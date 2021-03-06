//+------------------------------------------------------------------+

//|                                                       xea-maCCI-v1.1.mq4 |

//|                                                       xiaoxin003 |
//  (TimeCurrent()-prev_order_time)/60>=5*Period()
//|                                             sljxiaoxin@qq.com |
//  1、3条均线（60-100-200） + CCI指标
//  2、3条均线之上多，之下空。
//  3、之上通过CCI找买点（超卖点），并且价格不能高于100均线x点。
//  4、之下反之。
//  5、价格突破100均线或者穿破200均线（但未突破），趋势多不保，寻机会卖出。
//  6、加仓手数递减原则，分布加仓出仓。
//   bug:均线底买入，止损设置不对
//+------------------------------------------------------------------+
extern string   strVer                    = "xea-maCCI-v1.1";
extern string   strTips1                  = "建议欧元或日元15分钟图，止损15点";
extern string   strTips2                  = "黄金建议止损50点，大止盈";
extern bool     isBuy                     = true;
extern bool     isSell                    = true;
extern int      SL_Pips                   = 150;
extern int      TP_Pips1                  = 2000;
extern int      TP_Pips2                  = 800;
extern int      TP_Pips3                  = 800;
extern int      fastMa                    = 60;
extern int      slowMa                    = 100;
extern int      slowerMa                  = 200;
extern int      maMethod                  = 0;   //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern double   lots1                     = 0.03;
extern double   lots2                     = 0.02;
extern double   lots3                     = 0.01;
extern int      Max_Open_Orders           = 3;
extern string   strProfitLock_pips        = "赚多少点开始平保";
extern int      profitLock_pips           = 300;
extern string   strIsTrail                = "是否移动止损";
extern bool     isTrail                   = true;
extern int      trailStop_pips            = 200;   //每多少点涨一次
extern int      trailStep_pips            = 100;   //每次涨多少点
extern string   strBreakout_pips          = "突破点数";
extern int      breakout_pips             = 150;   //突破点数
extern int      gap_pips                  = 200;    //三条均线可买间隙点位
extern int      maxMaGap_pips             = 1000;  //100均线和200均线之间间隔最大值默认100点
extern int      trigger_pips              = 40;     //触发买卖点
extern int      trend_lasheng_pips        = 230;   //急剧拉升28点，急涨急跌标准值

int      max_spread                = 200;        //点差大于这个数禁止交易
int      PL_pips                   = 30;         //平保位于价格上点数

int      slippage                  = 5;          //最大滑点数

int       Magic_Number   = 20150531;
string    strComment     = "";
string    strTrend       = "no";
double    redrawtime     = 0;
double    preCCI         = 0;
int       stage          = 0; //阶段 用于判定手数
datetime prev_order_time = 1262278861;

bool     isJY            = false;  //程序判断是否可以交易
int      cci_Mode        = 0;     //1为超买，0为正常范围，-1为超卖
int      lasheng_index   = 0;     //急剧拉升的柱体索引值，0表示没有拉升，1表示上一个是拉升
double   lasheng_value   = 0;     //急剧拉升的区间值
double   lasheng_price   = 0;     //急剧拉升后的顶值
int sx = 1;
int init(){
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   profitLock_pips = profitLock_pips*sx;
   trailStop_pips  = trailStop_pips*sx;
   trailStep_pips  = trailStep_pips*sx;
   breakout_pips   = breakout_pips*sx;
   gap_pips        = gap_pips*sx;
   SL_Pips         = SL_Pips*sx;
   TP_Pips1        = TP_Pips1*sx;
   TP_Pips2        = TP_Pips2*sx;
   TP_Pips3        = TP_Pips3*sx;
   max_spread      = max_spread*sx;
   PL_pips         = PL_pips*sx;
   slippage        = slippage*sx;
   maxMaGap_pips   = maxMaGap_pips*sx;
   trigger_pips    = trigger_pips*sx;
   trend_lasheng_pips = trend_lasheng_pips*sx;
   judgeTrend();
   
}

int start(){
   getTradeInfo();
   if(checkAccountTrade()){
       if(redrawtime != Time[0]){
           judgeTrend();
           //preCCI = getCCI(1);
           redrawtime = Time[0];
           double l_fast_ma,l_slow_ma,l_slower_ma;
           l_fast_ma = iMA(Symbol(),0,fastMa,0,maMethod,PRICE_CLOSE,1);
           l_slow_ma = iMA(Symbol(),0,slowMa,0,maMethod,PRICE_CLOSE,1);
           l_slower_ma = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
           if(strTrend == "long"){
               close_sell_orders();
           }
           if(strTrend == "short"){
               close_buy_orders();
           }
           //getCciMode();
           //string cci_JY = pd_cci();
           if(lasheng_index >0){
               lasheng_index += 1;  //急剧拉升索引++
           }
           orderManage();  //订单管理
           trailStop();  //移动止损
           
       }
       lashengManage();  //急剧拉升管理
       if(strTrend == "long" && isBuy && isJY){
           if(allowBuy(l_fast_ma,l_slow_ma,l_slower_ma)){
               order_buy();
           }
       }
       if(strTrend == "short" && isSell && isJY){
           if(allowSell(l_fast_ma,l_slow_ma,l_slower_ma)){
               //卖点
               order_sell();
           }
       }
   }
   //trailStop();
   Comment(strComment);
   return 0;
}

/////////////////////////////////////////////////////////////
bool allowBuy(double l_fastMa, double l_slowMa, double l_slowerMa){
   if((Ask-l_fastMa>0 && Ask-l_fastMa <= trigger_pips*Point) || (Ask-l_slowMa>0 && Ask-l_slowMa <= trigger_pips*Point) || (Ask-l_slowerMa>0 && Ask-l_slowerMa <= trigger_pips*Point)){
      if(l_slowMa - l_slowerMa <maxMaGap_pips*Point){
         double lastBuyPrice = last_buy_price();
         if(Bid - lastBuyPrice >= 60*sx*Point || lastBuyPrice-Ask >=60*sx*Point){
            return true;
         }
      }
   }
   return false;
}
bool allowSell(double l_fastMa, double l_slowMa, double l_slowerMa){
   if((l_fastMa-Bid>0 && l_fastMa-Bid <= trigger_pips*Point) || (l_slowMa-Bid>0 && l_slowMa-Bid <= trigger_pips*Point) || (l_slowerMa-Bid>0 && l_slowerMa-Bid <= trigger_pips*Point)){
      if(l_slowerMa - l_slowMa < maxMaGap_pips*Point){
         double lastSellPrice = last_sell_price();
         if(lastSellPrice - Ask >= 60*sx*Point || Bid-lastSellPrice >=60*sx*Point){
            return true;
         }
      }
   }
   return false;
}
double last_buy_price()
{ 
   double ord_price=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()== Magic_Number 
         && OrderSymbol() == Symbol()
         && OrderType() == OP_BUY
         && OrderOpenPrice() > ord_price
        ) 
        ord_price = OrderOpenPrice();
   }
   
   return(ord_price);
}

double last_sell_price()
{ 
   double ord_price=999999;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()==Magic_Number 
         && OrderSymbol()==Symbol()
         && OrderType()==OP_SELL
         && OrderOpenPrice()<ord_price
        ){ 
            ord_price = OrderOpenPrice();
	}
   }
   return(ord_price);
}
void close_buy_orders()
{  
   int k=-1;
   int ord_arr[20];
   double ord_arrlots[20];
   int tries=0,oper_max_tries=30;
   bool OrderDeleted = false;
   for(int j=0;j<20;j++){
      ord_arr[j]=0;
      ord_arrlots[j] = 0;
   }
   int ot = OrdersTotal();
   for(j=0;j<ot;j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number)
      {   
         if(OrderType()==OP_BUY)   
         {  k = k + 1; 
            ord_arr[k]=OrderTicket();
            ord_arrlots[k]=OrderLots();
         }
      }     
    }
    for(j=0;j<=k;j++)
    {  OrderDeleted=false;
       tries=0;
       while(!OrderDeleted && tries<oper_max_tries)
       {
          OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Bid,5,Red);
          tries=tries+1;
       }
    }
}

void close_sell_orders()
{  
   int k=-1;
   int ord_arr[20];
   double ord_arrlots[20];
   int tries=0,oper_max_tries=30;
   bool OrderDeleted = false;
   for(int j=0;j<20;j++){
      ord_arr[j]=0;
      ord_arrlots[j] = 0;
   }
   int ot = OrdersTotal();
   for(j=0;j<ot;j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number)
      {   
         if(OrderType()==OP_SELL)   
         {  k = k + 1; 
            ord_arr[k]=OrderTicket();
            ord_arrlots[k]=OrderLots();
         }
      }     
    }
    for(j=0;j<=k;j++)
    {  OrderDeleted=false;
       tries=0;
       while(!OrderDeleted && tries<oper_max_tries)
       {
          OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Ask,5,Red);
          tries=tries+1;
       }
    }
}

void stage3_buy_close(){
   int tries=0,oper_max_tries=30;
   bool OrderDeleted = false;
   int ot = OrdersTotal();
   for(int j=0;j<ot;j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number && OrderComment() == "stage3_buy")
      {   
         int ticket = OrderTicket();
         while(!OrderDeleted && tries<oper_max_tries)
         {
            OrderDeleted = OrderClose(ticket,OrderLots(),Bid,slippage,Red);
            tries=tries+1;
         }
      }     
   }
}

void stage3_sell_close(){
  int tries=0,oper_max_tries=30;
  bool OrderDeleted = false;
  int ot = OrdersTotal();
  for(int j=0;j<ot;j++)
  {
     if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
     if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number && OrderComment() == "stage3_sell")
     {   
         int ticket = OrderTicket();
         while(!OrderDeleted && tries<oper_max_tries)
            {
               OrderDeleted = OrderClose(ticket,OrderLots(),Ask,slippage,Yellow);
               tries=tries+1;
            }
     }     
  }
}

int order_buy(){
   if(total_orders() >= Max_Open_Orders){
      return 0;
   }
   int NewOrder = 0;
   if(stage == 0){
       NewOrder = market_buy_order(SL_Pips, TP_Pips1, lots1, "stage1_buy");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage == 1 && (TimeCurrent()-prev_order_time)/60>=7*Period()){
       NewOrder = market_buy_order(SL_Pips, TP_Pips2, lots2, "stage2_buy");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage >1 && (TimeCurrent()-prev_order_time)/60>=7*Period()){
       NewOrder = market_buy_order(SL_Pips, TP_Pips3, lots3, "stage3_buy");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }
   return 0;
}

int order_sell(){
   if(total_orders() >= Max_Open_Orders){
      return 0;
   }
   int NewOrder = 0;
   if(stage == 0){
       NewOrder = market_sell_order(SL_Pips, TP_Pips1, lots1, "stage1_sell");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage == 1 && (TimeCurrent()-prev_order_time)/60>=7*Period()){
       NewOrder = market_sell_order(SL_Pips, TP_Pips2, lots2, "stage2_sell");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage >1 && (TimeCurrent()-prev_order_time)/60>=7*Period()){
       NewOrder = market_sell_order(SL_Pips, TP_Pips3, lots3, "stage3_sell");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }
   return 0;
}

int market_buy_order(double sl, double tp, double Lots, string memo)
{
   int NewOrder=0,tries=0,oper_max_tries=30;
   double sl_price=0,tp_price=0;
   if(sl == 0){
	   sl_price = 0;
   }else{
      sl_price = Bid - sl*Point;
   }
   if(tp == 0){
	   tp_price = 0;
   }else{
	   tp_price = Ask + tp*Point;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      Print("-------------buy:----sl:"+sl_price+";tp:"+tp_price);
      //RefreshRates();
      NewOrder = OrderSend(Symbol(),OP_BUY,Lots,Ask,slippage,sl_price,tp_price,memo,Magic_Number,0,Blue);            
      tries = tries+1;
   }
   Print("-------------buy result:"+NewOrder);
   if(NewOrder>0){
      prev_order_time = TimeCurrent();
   }
   return(NewOrder);
}

int market_sell_order(double sl, double tp, double Lots, string memo)
{
   int NewOrder=0,tries=0,oper_max_tries=30;
   double sl_price=0,tp_price=0;
   if(sl == 0){
	   sl_price = 0;
   }else{
      sl_price = Ask + sl*Point;
   }
   if(tp == 0){
	   tp_price = 0;
   }else{
	   tp_price = Bid - tp*Point;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      Print("-------------sell:----bid:"+Bid+";sl:"+sl_price+";tp:"+tp_price);
      RefreshRates();
      NewOrder = OrderSend(Symbol(),OP_SELL,Lots,Bid,slippage,sl_price,tp_price,memo,Magic_Number,0,White);            
      tries = tries+1;
   }
   Print("-------------sell result:"+NewOrder);
   if(NewOrder>0){
      prev_order_time = TimeCurrent();
   }
   return(NewOrder);
}

int total_orders()
{ 
   int tot_orders = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber() == Magic_Number 
         && OrderSymbol()==Symbol()
         && (OrderType()==OP_BUY || OrderType()==OP_SELL)
      )
      {
           tot_orders = tot_orders + 1;
      }
   }
   return(tot_orders);
}
//200均线以上为long，以下为short
void judgeTrend(){
   double l_slower_ma = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
   if(strTrend !="long" && Close[1] - l_slower_ma >= 80*sx*Point){
      strTrend = "long";
      isJY = true;
      stage = 0;
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
      prev_order_time = 1262278861;
      order_buy();
   }else if(strTrend !="short" && l_slower_ma - Close[1] >= 80*sx*Point){
      strTrend =  "short";
      isJY = true;
      stage = 0;
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
      prev_order_time = 1262278861;
      order_sell();
   }else{
   }
}

double getCCI(int i){
   double l_cci = iCCI(Symbol(),0,14,PRICE_TYPICAL,i);
   return l_cci;
}
void getCciMode(){
   double cci = getCCI(2);
   if(cci>50){
      cci_Mode = 1;
   }else if(cci<-50){
      cci_Mode = -1;
   }else{
      cci_Mode = 0;
   }
}
//cci判断，是否超买超卖后买点
string pd_cci(){
   double l_cci1,l_cci2,l_cci3;
   if(cci_Mode == 1){
      l_cci1 = getCCI(1);
      l_cci2 = getCCI(2);
      if(l_cci1<l_cci2){
         return "sell";
      }
   }
   if(cci_Mode == -1){
      l_cci1 = getCCI(1);
      l_cci2 = getCCI(2);
      if(l_cci1>l_cci2){
         return "buy";
      }
   }
   return "no";
}

void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认3条均线值:"+fastMa+"|"+slowMa+"|"+slowerMa;
    strComment += "\n买入价："+Bid;
    strComment += "\n卖出价："+Ask;
    strComment += "\n账户余额："+AccountBalance();
    strComment += "\n账户净值："+AccountEquity();
    strComment += "\n可用保证金："+AccountFreeMargin();
    strComment += "\n杠杆："+AccountLeverage();
    strComment += "\n点差："+getAsk_Bid()/Point;
    strComment += "\n今天周几："+DayOfWeek();
    strComment += "\n当前时间："+Hour()+":"+Minute();
    strComment += "\n当前CCI："+preCCI;
    strComment += "\n当前阶段："+stage;
    
}


//点差检测
double getAsk_Bid(){
   return (Ask - Bid);
}

//检测账户开单条件
bool checkAccountTrade(){
   if(AccountEquity() <=10 || AccountFreeMargin()<=5 || getAsk_Bid() > max_spread*Point){
	strComment += "\n账户净值或保证金不足 || 点差>"+max_spread+"，风险过大！";
	return false;
   }else{
	return true;
   }
}

//根据ticket关闭订单
void close_order_byTicket(int ticket, int orderType){
   int tries=0,oper_max_tries=4;
   bool OrderDeleted = false;
   if(orderType == OP_BUY){
      while(!OrderDeleted && tries<oper_max_tries){
         OrderClose(ticket,OrderLots(),Bid,slippage,Red);
         tries = tries+1;
      }
   }else if(orderType == OP_SELL){
      while(!OrderDeleted && tries<oper_max_tries){
         OrderDeleted = OrderClose(ticket,OrderLots(),Ask,slippage,Yellow);
         tries = tries+1;
      }
   }
}
//订单管理
void orderManage(){
   datetime orderOpenTime;
   double   orderProfit;
   double   orderOpenPrice;
   int ticket;
   //1、开单后5根，未盈利的出局
   for (int i=0; i<OrdersTotal(); i++) {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {     
            if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol()){
               if((OrderType() == OP_BUY || OrderType() == OP_SELL) && (OrderComment() == "stage3_sell" || OrderComment() == "stage3_buy")){
                  orderOpenTime  = OrderOpenTime(); 
                  if((TimeCurrent()-orderOpenTime)/60>=15*Period()){
                     //开单时间已超过5根柱子
                     orderOpenPrice = OrderOpenPrice();
                     orderProfit = OrderProfit();
                     if(orderProfit <0 && MathAbs(Ask - orderOpenPrice)>150*sx*Point){
                           ticket = OrderTicket();
                           close_order_byTicket(ticket,OrderType());
                           Print("--开单后15根未盈利出局:"+ticket);
                     }
                  }
               }
            }
         }
      }
     //2、急剧拉升/下跌后处理
     if(strTrend == "long"){
         if(Close[1]>Open[1]){
            for(i=2;i<=5;i++){
               if(Close[i]<Open[i]){
                  break;
               }
            }
            if(Close[1] - Open[i-1] >= trend_lasheng_pips*Point){
               lasheng_index = 1;  //急剧拉升索引
               lasheng_value = Close[1] - Open[i-1];  //区间
               lasheng_price = Close[1]; //拉升后顶值
            }
         }
         
     }
     if(strTrend == "short"){
         if(Open[1]>Close[1]){
            for(i=2;i<=5;i++){
               if(Close[i]>Open[i]){
                  break;
               }
            }
            if(Open[i-1] - Close[1] >= trend_lasheng_pips*Point){
               lasheng_index = 1;  //急剧拉升索引
               lasheng_value = Open[i-1] - Close[1];   //区间
               lasheng_price = Close[1];
            }
         }
         
     }
     //3、上影线和下影线处理
     if(strTrend == "long"){
         if(Open[1]>Close[1] && High[1]-Open[1]>80*sx*Point && High[1]-Open[1]>=3*(Open[1]-Close[1])){
            if(iHighest(NULL,0,MODE_HIGH,20,1) <= 4){
               close_buy_orders();
            }else{
               stage3_buy_close();
            }
         }
     }
     if(strTrend == "short"){
         if(Open[1]<Close[1] && Open[1]-Low[1]>80*sx*Point && Open[1]-Low[1]>=3*(Close[1]-Open[1])){
            if(iLowest(NULL,0,MODE_LOW,20,1) <= 4){
               close_sell_orders();  //发生于20根柱最低点
            }else{
               stage3_sell_close();  //其他点附近
            }
         }
     }
     //4、连续上涨/下跌5次出局
     bool isLianXu5 = true;
     if(strTrend == "long"){
         if(Open[5]-Close[1] >250*sx*Point){
            for(i=1;i<=5;i++){
               if(Open[i]<Close[i]){
                  isLianXu5 = false;
                  break;
               }
            }
         }else{
            isLianXu5 = false;
         }
         if(isLianXu5){
            close_buy_orders();
            Print("--连续下跌5次出局，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
         }
     }
     if(strTrend == "short"){
         if(Close[1]-Open[5] >250*sx*Point){
            for(i=1;i<=5;i++){
               if(Open[i]>Close[i]){
                  isLianXu5 = false;
                  break;
               }
            }
         }else{
            isLianXu5 = false;
         }
         if(isLianXu5){
            close_sell_orders();
            Print("--连续上涨5次出局，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
         }
     }
     //5、前两根加起来是急拉值的3倍则盈利走人
   if(strTrend == "long" && (Bid - Open[0] >= 3*trend_lasheng_pips*Point || Bid - Open[1] >= 3*trend_lasheng_pips*Point)){
      //当前急剧拉升3倍急拉值，直接close
      close_buy_orders();
      Print("--急剧拉升3倍急拉值，直接获利了结，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
      return false;
   }
   if(strTrend == "short" && (Open[0] - Ask >= 3*trend_lasheng_pips*Point || Open[1] - Ask >= 3*trend_lasheng_pips*Point)){
      //当前急剧拉升3倍急拉值，直接close
      close_sell_orders();
      Print("--急剧拉升3倍急拉值，直接获利了结，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
      return false;
   }
     
     
     
}

//急剧拉升管理
bool lashengManage(){
   //1、正方向拉升获利了结
   if(strTrend == "long" && (Bid - Open[0] >= 6*trend_lasheng_pips*Point || Bid - Open[1] >= 6*trend_lasheng_pips*Point)){
      //当前急剧拉升6倍急拉值，直接close
      close_buy_orders();
      Print("--急剧拉升6倍急拉值，直接获利了结，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
      return false;
   }
   if(strTrend == "short" && (Open[0] - Ask >= 6*trend_lasheng_pips*Point || Open[1] - Ask >= 6*trend_lasheng_pips*Point)){
      //当前急剧拉升3倍急拉值，直接close
      close_sell_orders();
      Print("--急剧拉升6倍急拉值，直接获利了结，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
      return false;
   }
   //2、反方向急剧拉30点，平仓走人
   if(strTrend == "long" && Ask < Open[0] && High[0]-Ask>400*sx*Point){
      //反方向大于40点走人
      close_buy_orders();
      isJY = false;  //暂时禁止交易
   }
   if(strTrend == "short" && Bid > Open[0] && Bid-Low[0]>400*sx*Point){
      //反方向大于40点走人
      close_sell_orders();
      isJY = false;   //暂时禁止交易
   }
   //3、拉升后回调38.2%关闭
   if(lasheng_index == 0 || lasheng_index>5){
      return false;
   }else{
      if(strTrend == "long"){
         if(Ask > lasheng_price){
            return false;
         }else{
            //计算如果回调38.2%则平仓
            if(lasheng_price - Ask > lasheng_value*0.382){
               //下平仓指令
               //TODO............................
               close_buy_orders();
               Print("--拉升后回调超过38.2%关闭buy，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
               lasheng_index = 0;
               lasheng_value = 0;
               lasheng_price = 0;
            }
         }
      }
      if(strTrend == "short"){
         if(Bid < lasheng_price){
            return false;
         }else{
            //计算如果回调38.2%则平仓
            if(Bid - lasheng_price > lasheng_value*0.382){
               //下平仓指令
               //TODO............................
               close_sell_orders();
               Print("--拉升后回调超过38.2%关闭sell，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
               lasheng_index = 0;
               lasheng_value = 0;
               lasheng_price = 0;
            }
         }
      }
   }
   
}
//移动止损
void trailStop(){
   if(isTrail && strTrend != "no"){
      double x,y,newSL,newSLy;
      double openPrice,myStopLoss;
      for (int i=0; i<OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {     
         if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol()){
            if(OrderType() == OP_BUY){
		         openPrice = OrderOpenPrice();
		         myStopLoss = OrderStopLoss();
               if(myStopLoss<openPrice && Bid - openPrice > profitLock_pips*Point){
                  //设置平保
                  newSL = openPrice+PL_pips*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
               }
               if(Bid - openPrice > trailStop_pips*Point){
                  //按比例移动止损
                  x = (Bid - openPrice)/(trailStop_pips*Point);
                  newSL = (openPrice-SL_Pips*Point)+x*trailStep_pips*Point;
                  if(myStopLoss + trailStep_pips*Point < newSL){
                     OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  }
               }
            }
            if(OrderType() == OP_SELL){
	            openPrice = OrderOpenPrice();
	            myStopLoss = OrderStopLoss();
               if(myStopLoss>openPrice && openPrice-Ask > profitLock_pips*Point){
                  //设置平保
                  newSL = openPrice - PL_pips*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
               }
               if(openPrice - Ask > trailStop_pips*Point){
                  y = (openPrice - Ask)/(trailStop_pips*Point);
                  newSLy = (openPrice+SL_Pips*Point)-y*trailStep_pips*Point;
                  if(myStopLoss-trailStep_pips*Point>newSLy){
                     OrderModify(OrderTicket(),openPrice,newSLy, OrderTakeProfit(), 0);
                  }
               }
            }
         }
      }
     }
   }
}