//+------------------------------------------------------------------+

//|                                               xea-mtframe-zg.mq4 |
   //大周期判反向，小周期trade
   //大大周期找zigzag高低点
//+------------------------------------------------------------------+
extern string   strVer            = "xea-mtframe-zg";
extern int Magic_Number           = 20150831;
extern int      SL_Pips           = 200;
extern int      TP_Pips1          = 2000;
extern int      TP_Pips2          = 800;
extern int      TP_Pips3          = 600;
extern int fastFrame_fastMa       = 60;
extern int fastFrame_slowMa       = 120;
extern int fastFrame_slowerMa     = 200;
extern int slowFrame_Ma           = 200;
extern double   lots1             = 0.03;
extern double   lots2             = 0.02;
extern double   lots3             = 0.01;
extern int      Max_Open_Orders   = 3;
extern int      maMethod          = 0;   //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern int      trigger_pips      = 40;     //触发买卖点
extern int      trend_lasheng_pips        = 230;   //急剧拉升28点，急涨急跌标准值



extern int ExtDepth = 6;
extern int ExtDeviation = 5;
extern int ExtBackstep = 3;

double ZigzagBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];
extern int zg_Bars = 180;


int fastFrame   = PERIOD_M5;    //5     交易周期
int slowFrame   = PERIOD_H1;    //60    方向周期
int slowerFrame = PERIOD_D1;    //1440  支阻周期
string tradeType = "none";      //buy sell none
bool tradeOver   = false;       
double fastFrame_openTime=0,slowFrame_openTime=0,slowerFrame_openTime=0;
double arrZigzagHigh[]; //高点数组
double arrZigzagLow[];  //低点数组 
int sx  = 1;
double l_fast_ma,l_slow_ma,l_slower_ma;

string    strComment     = "";
string    strTrend       = "";
int       max_spread     = 200;        //点差大于这个数禁止交易
int       stage          = 0;          //阶段 用于判定手数
int       slippage       = 5;          //最大滑点数
datetime prev_order_time = 1262278861;
int      lasheng_index   = 0;     //急剧拉升的柱体索引值，0表示没有拉升，1表示上一个是拉升
double   lasheng_value   = 0;     //急剧拉升的区间值
double   lasheng_price   = 0;     //急剧拉升后的顶值


int init(){
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   trigger_pips    = trigger_pips*sx;
   max_spread      = max_spread*sx;
   SL_Pips         = SL_Pips*sx;
   TP_Pips1        = TP_Pips1*sx;
   TP_Pips2        = TP_Pips2*sx;
   TP_Pips3        = TP_Pips3*sx;
   trend_lasheng_pips = trend_lasheng_pips*sx;
   ///////////////////////////////////
   ArrayResize(HighMapBuffer,zg_Bars);
   ArrayResize(LowMapBuffer,zg_Bars);
   ArrayInitialize(HighMapBuffer,0.0);
   ArrayInitialize(LowMapBuffer,0.0);
   return 0;
}

int start(){
   
   if(tradeOver || !checkAccountTrade()){return 0;}
   //D1
   if(slowerFrame_openTime != iTime(NULL,slowerFrame,0)){
      slowerFrame_openTime = iTime(NULL,slowerFrame,0);
      getZigzag(); //获取高低点
   }
   //H1
   if(slowFrame_openTime != iTime(NULL,slowFrame,0)){
      slowFrame_openTime = iTime(NULL,slowFrame,0);
      double h1_ma = iMA(Symbol(),slowFrame,slowFrame_Ma,0,maMethod,PRICE_CLOSE,1);
      if(iClose(NULL,slowFrame,1) - h1_ma >0){
         if(tradeType == "sell"){
            stage = 0;
            lasheng_index = 0;
            lasheng_value = 0;
            lasheng_price = 0;
         }
         tradeType = "buy";
      }
      if(iClose(NULL,slowFrame,1) - h1_ma <0){
         if(tradeType == "buy"){
            stage = 0;
            lasheng_index = 0;
            lasheng_value = 0;
            lasheng_price = 0;
         }
         tradeType = "sell";
      }
   }
   //M5
   if(fastFrame_openTime != Time[0]){
      fastFrame_openTime = Time[0];
      l_fast_ma = iMA(Symbol(),0,fastFrame_fastMa,0,maMethod,PRICE_CLOSE,1);
      l_slow_ma = iMA(Symbol(),0,fastFrame_slowMa,0,maMethod,PRICE_CLOSE,1);
      l_slower_ma = iMA(Symbol(),0,fastFrame_slowerMa,0,maMethod,PRICE_CLOSE,1);
      judgeTrend();
      orderManage();
   }
   lashengManage();  //急剧拉升管理
   tradeRun();
   
   ///////////////////////////////////////////////////
   getTradeInfo();
   Comment(strComment);
   return 0;
}

void tradeRun(){
   if(tradeType == "buy"){
      if(strTrend == "long"){
         //一小时向上，并且5分钟向上
         if(allowBuy()){
            order_buy();  //买
         }
      }
   }
   if(tradeType == "sell"){
      if(strTrend == "short"){
         if(allowSell()){
            order_sell();  //卖
         }
      }
   }
   
}

bool allowBuy(){
   
   if((Ask-l_fast_ma>0 && Ask-l_fast_ma <= trigger_pips*Point) || (Ask-l_slow_ma>0 && Ask-l_slow_ma <= trigger_pips*Point) || (Ask-l_slower_ma>0 && Ask-l_slower_ma <= trigger_pips*Point)){
      if(total_orders() == 0){
         return true;
      }else{
         double lastBuyPrice = last_buy_price();
         if(Bid - lastBuyPrice >= 60*sx*Point || lastBuyPrice-Ask >=60*sx*Point){
            return true;
         }
      }
   }
   return false;
}

bool allowSell(){
   
   if((l_fast_ma-Bid>0 && l_fast_ma-Bid <= trigger_pips*Point) || (l_slow_ma-Bid>0 && l_slow_ma-Bid <= trigger_pips*Point) || (l_slower_ma-Bid>0 && l_slower_ma-Bid <= trigger_pips*Point)){
      if(total_orders() == 0){
         return true;
      }else{
         double lastSellPrice = last_sell_price();
         if(lastSellPrice - Ask >= 60*sx*Point || Bid-lastSellPrice >=60*sx*Point){
            return true;
         }
      }
   }
   return false;
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
   }else if(stage == 1 && (TimeCurrent()-prev_order_time)/60>=20*Period()){
       NewOrder = market_buy_order(SL_Pips, TP_Pips2, lots2, "stage2_buy");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage >1 && stage<15 && (TimeCurrent()-prev_order_time)/60>=20*Period()){
       NewOrder = market_buy_order(SL_Pips, TP_Pips3, lots3, "stage3_buy");
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
   }else if(stage == 1 && (TimeCurrent()-prev_order_time)/60>=20*Period()){
       NewOrder = market_sell_order(SL_Pips, TP_Pips2, lots2, "stage2_sell");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage >1 && stage<15 && (TimeCurrent()-prev_order_time)/60>=20*Period()){
       NewOrder = market_sell_order(SL_Pips, TP_Pips3, lots3, "stage3_sell");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }
   return 0;
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

//判断M5-Trend
void judgeTrend(){
   if(l_fast_ma>l_slower_ma && l_slow_ma>l_slower_ma){
      strTrend = "long";
      close_sell_orders();
   }else if(l_fast_ma<l_slower_ma && l_slow_ma<l_slower_ma){
      strTrend = "short";
      close_buy_orders();
   }else{
      strTrend = "";
   }
}

void getZigzag(){
   int limit;
   int shift,back;
   double val,res;
   double lasthigh,lastlow;
   //string var1;
   limit = zg_Bars - ExtDepth;
   for(shift=limit; shift>=4; shift--)
   {
      val=iLow(NULL,slowerFrame,iLowest(NULL,slowerFrame,MODE_LOW,ExtDepth,shift));
      if(val==lastlow) val=0.0;
      else 
        { 
         lastlow=val; 
         if((iLow(NULL,slowerFrame,shift)-val)>(ExtDeviation*Point)) val=0.0;
         else
           {
            for(back=1; back<=ExtBackstep; back++)
              {
               res=LowMapBuffer[shift+back];
               if((res!=0)&&(res>val)) LowMapBuffer[shift+back]=0.0; 
              }
           }
        } 
      if (iLow(NULL,slowerFrame,shift)==val) LowMapBuffer[shift]=val; else LowMapBuffer[shift]=0.0;
      //--- high
      val=iHigh(NULL,slowerFrame,iHighest(NULL,slowerFrame,MODE_HIGH,ExtDepth,shift));
      if(val==lasthigh) val=0.0;
      else 
        {
         lasthigh=val;
         if((val-iHigh(NULL,slowerFrame,shift))>(ExtDeviation*Point)) val=0.0;
         else
           {
            for(back=1; back<=ExtBackstep; back++)
              {
               res=HighMapBuffer[shift+back];
               if((res!=0)&&(res<val)) HighMapBuffer[shift+back]=0.0; 
              } 
           }
        }
      if (iHigh(NULL,slowerFrame,shift)==val) HighMapBuffer[shift]=val; else HighMapBuffer[shift]=0.0;
   }
   //整理为高低点相隔的顺序，去除例如高点高点低点的顺序
   int gd = 0; //1高2低
   double gd_val = 0.0;
   int gd_idx = 0;
   int g_count = 0; //高点个数
   int d_count = 0; //低点个数
   for(int i=limit;i>=4;i--){
         //高低点整理
       if(LowMapBuffer[i] >0){
          if(gd == 0 || gd ==1){
             d_count += 1; 
             gd = 2;
             gd_idx = i;
             gd_val = LowMapBuffer[i];
          }
          else if(gd == 2){
             if(LowMapBuffer[i]<=gd_val){
               LowMapBuffer[gd_idx] = 0.0;
               gd_idx = i;
               gd_val = LowMapBuffer[i];
             }
             if(LowMapBuffer[i]>gd_val){
               LowMapBuffer[i] = 0.0;
             }
             
          }
       }
       if(HighMapBuffer[i] >0){
          if(gd == 0 || gd ==2){
             g_count += 1;
             gd = 1;
             gd_idx = i;
             gd_val = HighMapBuffer[i];
          }
          else if(gd == 1){
             if(HighMapBuffer[i]>=gd_val){
               HighMapBuffer[gd_idx] = 0.0;
               gd_idx = i;
               gd_val = HighMapBuffer[i];
             }
             if(HighMapBuffer[i]<gd_val){
               HighMapBuffer[i] = 0.0;
             }
             
          }
       }
   }
   setZigzagText(limit);
   //int g_dataIndex[];
   //int d_dataIndex[];
   int g_fori = 0;
   int d_fori = 0;
   ArrayResize(arrZigzagHigh, g_count);
   ArrayResize(arrZigzagLow, d_count);
   //ArrayResize(g_dataIndex,g_count);
   //ArrayResize(d_dataIndex,d_count);
   for(i=0;i<=limit;i++){
      if(LowMapBuffer[i] >0){
         arrZigzagLow[d_fori] = LowMapBuffer[i];
         //d_dataIndex[d_fori] = i;
         d_fori++;
      }
      if(HighMapBuffer[i]>0){
         arrZigzagHigh[g_fori] = HighMapBuffer[i];
         //g_dataIndex[g_fori] = i;
         g_fori++;
      }
   }
   
}

//画线
void setZigzagText(int limit){
     //删除文本
     ObjectsDeleteAll(0, OBJ_TEXT);
     for(int mm=limit;mm>=4;mm--){
        if(LowMapBuffer[mm] >0){
            ObjectCreate("text_object"+mm, OBJ_TEXT, 0, iTime(NULL,slowerFrame,mm), iLow(NULL,slowerFrame,mm));
            ObjectSetText("text_object"+mm, "低点", 10, "Times New Roman", Red);
        }
        if(HighMapBuffer[mm] >0){
            //var1=TimeToStr(Time[i],TIME_DATE|TIME_SECONDS);
            //Print("High time = "+var1+"; index = "+i+" ; value = "+HighMapBuffer[i]);
            ObjectCreate("text_object"+mm, OBJ_TEXT, 0, iTime(NULL,slowerFrame,mm), iHigh(NULL,slowerFrame,mm)+50*Point*sx);
            ObjectSetText("text_object"+mm, "高点", 10, "Times New Roman", White);
        }
     }
}

void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认3条均线值:"+fastFrame_fastMa+"|"+fastFrame_slowMa+"|"+fastFrame_slowerMa;
    //strComment += "\n买入价："+Bid;
    //strComment += "\n卖出价："+Ask;
    strComment += "\n交易方向："+tradeType;
    strComment += "\ntrend方向："+strTrend;
    strComment += "\n账户余额："+AccountBalance();
    strComment += "\n账户净值："+AccountEquity();
    strComment += "\n可用保证金："+AccountFreeMargin();
    strComment += "\n杠杆："+AccountLeverage();
    strComment += "\n点差："+getAsk_Bid()/Point;
    strComment += "\n今天周几："+DayOfWeek();
    strComment += "\n当前时间："+Hour()+":"+Minute();
    strComment += "\n当前阶段："+stage;
    strComment += "\n高点前三："+arrZigzagHigh[0]+"|"+arrZigzagHigh[1]+"|"+arrZigzagHigh[2];
    strComment += "\n低点前三："+arrZigzagLow[0]+"|"+arrZigzagLow[1]+"|"+arrZigzagLow[2];
    
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
                     //开单时间已超过15根柱子
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
     if(tradeType == "buy" && strTrend == "long"){
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
     if(tradeType == "sell" && strTrend == "short"){
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
     if(tradeType == "buy" && strTrend == "long"){
         if(Open[1]>Close[1] && High[1]-Open[1]>80*sx*Point && High[1]-Open[1]>=3*(Open[1]-Close[1])){
            if(iHighest(NULL,0,MODE_HIGH,20,1) <= 4){
               Print("--上影线且20根最高点附近则全部出局");
               close_buy_orders();
            }else{
               Print("--上影线stage3出局");
               stage3_buy_close();
            }
         }
     }
     if(tradeType == "sell" && strTrend == "short"){
         if(Open[1]<Close[1] && Open[1]-Low[1]>80*sx*Point && Open[1]-Low[1]>=3*(Close[1]-Open[1])){
            if(iLowest(NULL,0,MODE_LOW,20,1) <= 4){
               Print("--下影线且20根最低点附近则全部出局");
               close_sell_orders();  //发生于20根柱最低点
            }else{
               Print("--下影线stage3出局");
               stage3_sell_close();  //其他点附近
            }
         }
     }
     //4、连续上涨/下跌5次出局
     bool isLianXu5 = true;
     if(tradeType == "buy" && strTrend == "long"){
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
     if(tradeType == "sell" && strTrend == "short"){
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
   if(tradeType == "buy" && strTrend == "long" && (Bid - Open[0] >= 3*trend_lasheng_pips*Point || Bid - Open[1] >= 3*trend_lasheng_pips*Point)){
      //当前急剧拉升3倍急拉值，直接close
      close_buy_orders();
      Print("--急剧拉升3倍急拉值，直接获利了结，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
   }
   if(tradeType == "sell" && strTrend == "short" && (Open[0] - Ask >= 3*trend_lasheng_pips*Point || Open[1] - Ask >= 3*trend_lasheng_pips*Point)){
      //当前急剧拉升3倍急拉值，直接close
      close_sell_orders();
      Print("--急剧拉升3倍急拉值，直接获利了结，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
   }
     
     
     
}

//急剧拉升管理
bool lashengManage(){
   //1、正方向拉升获利了结
   if(tradeType == "buy" && strTrend == "long" && (Bid - Open[0] >= 6*trend_lasheng_pips*Point || Bid - Open[1] >= 6*trend_lasheng_pips*Point)){
      //当前急剧拉升6倍急拉值，直接close
      close_buy_orders();
      Print("--急剧拉升6倍急拉值，直接获利了结，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
      prev_order_time = TimeCurrent();
      return false;
   }
   if(tradeType == "sell" && strTrend == "short" && (Open[0] - Ask >= 6*trend_lasheng_pips*Point || Open[1] - Ask >= 6*trend_lasheng_pips*Point)){
      //当前急剧拉升6倍急拉值，直接close
      close_sell_orders();
      Print("--急剧拉升6倍急拉值，直接获利了结，时间:"+TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      lasheng_index = 0;
      lasheng_value = 0;
      lasheng_price = 0;
      prev_order_time = TimeCurrent();
      return false;
   }
   //2、反方向急剧拉40点，平仓走人
   if(tradeType == "buy" && strTrend == "long" && Ask < Open[0] && High[0]-Ask>400*sx*Point){
      //反方向大于40点走人
      close_buy_orders();
      prev_order_time = TimeCurrent();
   }
   if(tradeType == "sell" && strTrend == "short" && Bid > Open[0] && Bid-Low[0]>400*sx*Point){
      //反方向大于40点走人
      close_sell_orders();
      prev_order_time = TimeCurrent();
   }
   //3、拉升后回调38.2%关闭
   if(lasheng_index == 0 || lasheng_index>5){
      return false;
   }else{
      if(tradeType == "buy" && strTrend == "long"){
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
               prev_order_time = TimeCurrent();
            }
         }
      }
      if(tradeType == "sell" && strTrend == "short"){
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
               prev_order_time = TimeCurrent();
            }
         }
      }
   }
   
}