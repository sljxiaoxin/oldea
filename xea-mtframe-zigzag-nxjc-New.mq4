//+------------------------------------------------------------------+

//|                                               xea-mtframe-zg-nxjc.mq4 |
   //大周期判反向，小周期trade
   //大大周期找zigzag高低点
//+------------------------------------------------------------------+
extern string   strVer            = "xea-mtframe-zg-nxjc";
extern int Magic_Number           = 20150908;
extern int      SL_Pips           = 0;
extern int      TP_Pips           = 600;
extern int fastFrame_fastMa       = 60;
extern int fastFrame_slowMa       = 120;
extern int fastFrame_slowerMa     = 200;
extern int slowFrame_Ma           = 60;
extern double   lots              = 0;
extern int      Max_Open_Orders   = 5;
extern int      maMethod          = 0;   //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern int      trigger_pips      = 40;     //触发买卖点
extern int      trend_lasheng_pips        = 120;   //急剧拉升28点，急涨急跌标准值



extern int ExtDepth = 6;
extern int ExtDeviation = 5;
extern int ExtBackstep = 3;

double ZigzagBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];
extern int zg_Bars = 180;


int fastFrame   = PERIOD_M5;    //5     交易周期
int slowFrame   = PERIOD_H1;    //60    方向周期
int slowerFrame = PERIOD_H1;    //1440  支阻周期
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
bool    isChanged = false;
double h1_ma1,h1_ma2,h1_ma3;
bool isCanFirst = false;  //趋势发生逆转，可以开始第一单
bool isSuperMgr = false;
int init(){
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   trigger_pips    = trigger_pips*sx;
   max_spread      = max_spread*sx;
   SL_Pips         = SL_Pips*sx;
   TP_Pips         = TP_Pips*sx;
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
      //getZigzag(); //获取高低点
   }
   //H1
   if(slowFrame_openTime != iTime(NULL,slowFrame,0)){
      slowFrame_openTime = iTime(NULL,slowFrame,0);
      isSuperMgr = true;
      h1_ma1 = iMA(Symbol(),slowFrame,slowFrame_Ma,0,maMethod,PRICE_CLOSE,1);
      h1_ma2 = iMA(Symbol(),slowFrame,slowFrame_Ma,0,maMethod,PRICE_CLOSE,2);
      h1_ma3 = iMA(Symbol(),slowFrame,slowFrame_Ma,0,maMethod,PRICE_CLOSE,3);
      if(iClose(NULL,slowFrame,3) - h1_ma3 >=0 && iLow(NULL,slowFrame,2) -h1_ma2>=0 && iLow(NULL,slowFrame,1) -h1_ma1>=0 ){
         if(tradeType == "sell"){
            stage = 0;
            isCanFirst = true;
            //关闭所有卖出单
            close_sell_orders();
         }
         stage+=1;
         if(stage > 10){
            isCanFirst = false;
         }
         tradeType = "buy";
      }
      if(iClose(NULL,slowFrame,3) - h1_ma3 <=0 && iHigh(NULL,slowFrame,2) - h1_ma2 <=0 && iHigh(NULL,slowFrame,1) - h1_ma1 <=0 ){
         if(tradeType == "buy"){
            stage = 0;
            isCanFirst = true;
            //关闭所有买单
            close_buy_orders();
         }
         stage+=1;
         if(stage > 10){
            isCanFirst = false;
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
      string strTrendTmp = strTrend;
      judgeTrend();
      //isChanged = false;
      if(strTrend != strTrendTmp){
         isChanged = true;
      }
      trailStop();
   }
   orderMgr();
   tradeRun();
   
   ///////////////////////////////////////////////////
   
   getTradeInfo();
   Comment(strComment);
   return 0;
}

void first_buy(){
   if(!isCanFirst){
      return;
   }
   if(Ask-h1_ma1>0 && Ask-h1_ma1<=150*sx*Point){
      if(l_fast_ma>l_slower_ma && l_slow_ma>l_slower_ma && 
       ((Ask-l_fast_ma >0 && Ask-l_fast_ma <= trigger_pips*Point) || 
       (Ask-l_slow_ma >0 && Ask-l_slow_ma <= trigger_pips*Point) || 
       (Ask-l_slower_ma >0 && Ask-l_slower_ma <= trigger_pips*Point))){
          double realLots = getLots();
          market_buy_order(250*sx, 1200*sx, realLots*2, "FirstBuy");
          isCanFirst = false;
          Print("--趋势第一个买单！");
      }   
   } 
}

void first_sell(){
   if(!isCanFirst){
      return;
   }
   if(h1_ma1 - Bid>0 && h1_ma1 - Bid<=150*sx*Point){
      if(l_fast_ma<l_slower_ma && l_slow_ma<l_slower_ma && 
       ((l_fast_ma -Bid >0 && l_fast_ma -Bid <= trigger_pips*Point) || 
       (l_slow_ma-Bid >0 && l_slow_ma-Bid <= trigger_pips*Point) || 
       (l_slower_ma-Bid >0 && l_slower_ma-Bid <= trigger_pips*Point))){
          double realLots = getLots();
          market_sell_order(250*sx, 1200*sx, realLots*2, "FirstSell");
          isCanFirst = false;
          Print("--趋势第一个卖单！");
      }   
   }
}

void tradeRun(){
   string type = "";
   if(tradeType == "buy"){
      first_buy();
      if(strTrend == "short"){
         if(allowBuy()){
            order_buy();  //买
         }
      }
      if(strTrend == "long" && isChanged){
         if(total_orders() >= 2){
            isChanged = false;
            return;
         }
         //刚变为long
         if(Bid-l_slower_ma>0 && Bid-l_slower_ma <= trigger_pips*Point && (TimeCurrent()-prev_order_time)/60>=30*Period()){
            Print("--趋势逆转购买");
            order_buy();  //买
            isChanged = false;
         }
      }
      if(strTrend == "long"){
         //刚变为long
         if(((Ask-l_slower_ma>0 && Ask-l_slower_ma <= trigger_pips*Point) || (Ask-l_slow_ma>0 && Ask-l_slow_ma <= trigger_pips*Point)) && (TimeCurrent()-prev_order_time)/60>=20*Period() && total_orders()<=1){
            Print("--趋势无开单购买");
            order_buy();  //买
         }
      }
   }
   if(tradeType == "sell"){
      first_sell();
      if(strTrend == "long"){
         if(allowSell()){
            order_sell();  //卖
         }
      }
      if(strTrend == "short" && isChanged){
         if(total_orders() >= 2){
            isChanged = false;
            return;
         }
         //刚变为long
         if(l_slower_ma-Ask>0 && l_slower_ma-Ask <= trigger_pips*Point && (TimeCurrent()-prev_order_time)/60>=30*Period()){
            Print("--趋势逆转卖出");
            order_sell();  //买
            isChanged = false;
         }
      }
      if(strTrend == "short"){
         //刚变为long
         if(((l_slower_ma-Bid>0 && l_slower_ma-Bid <= trigger_pips*Point) || (l_slow_ma-Bid>0 && l_slow_ma-Bid <= trigger_pips*Point)) && (TimeCurrent()-prev_order_time)/60>=20*Period() && total_orders()<=1){
            Print("--趋势无开单卖出");
            order_sell();
         }
      }
   }
   
}

bool allowBuy(){
   
   if((TimeCurrent()-prev_order_time)/60<20*Period()){
      //Print("--距离上次不足20根");
      return false;
   }
   if(total_orders() >= Max_Open_Orders){
      Print("--已开单最大值");
      return false;
   }
   if(l_fast_ma<l_slower_ma && l_slow_ma<l_slower_ma && l_fast_ma<l_slow_ma){
      //当前价格<fast_ma并且小于一定范围
      if(l_fast_ma - Close[1]> 0){
           if(Open[1]>Close[1] && l_fast_ma-Low[1]>250*sx*Point){
               for(int i=2;i<=5;i++){
                  if(Close[i]>Open[i]){
                     break;
                  }
               }
               if(Open[i-1] - Close[1] >= trend_lasheng_pips*Point){
                  if(Bid - Open[0] >0){
                     return true;
                  }
               }
            }
      }
   }
   if(l_fast_ma<l_slower_ma){
      if(l_fast_ma - Low[1]>350*sx*Point && (Close[1] - Low[1]>=70*sx*Point || Close[1]-Open[1]>0)){
         if(l_fast_ma - Bid >= 250*sx*Point){
            return true;
         }
      }
   }
   return false;

}

bool allowSell(){
   if((TimeCurrent()-prev_order_time)/60<20*Period()){
      //Print("--距离上次不足20根");
      return false;
   }
   if(total_orders() >= Max_Open_Orders){
      Print("--已开单最大值");
      return false;
   }
   if(l_fast_ma>l_slower_ma && l_slow_ma>l_slower_ma && l_fast_ma>l_slow_ma){
       if(Close[1]>Open[1] && High[1] - l_fast_ma>250*sx*Point){
         for(int i=2;i<=5;i++){
            if(Close[i]<Open[i]){
               break;
            }
         }
         if(Close[1] - Open[i-1] >= trend_lasheng_pips*Point){
             if(Open[0] - Ask >0){
               return true;
             }
         }
      }
   }
   if(l_fast_ma>l_slower_ma){
      if(High[1] - l_fast_ma>=350*sx*Point && (High[1] - Close[1]>=70*sx*Point || Close[1]-Open[1]<0)){
         if(Ask - l_fast_ma >= 250*sx*Point){
            return true;
         }
      }
   }
   return false;
}
int order_buy(){
   int NewOrder = 0;
   double realLots = getLots();
   NewOrder = market_buy_order(SL_Pips, TP_Pips, realLots, "buy");
   if(NewOrder >0){
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
   int NewOrder = 0;
   double realLots = getLots();
   NewOrder = market_sell_order(SL_Pips, TP_Pips, realLots, "sell");
   if(NewOrder >0){
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
   if(strTrend == ""){
      if(Close[1] - l_slower_ma>0){
         strTrend = "long";
      }
      if(Close[1] - l_slower_ma<0){
          strTrend = "short";
      }
   }else{
      if(Close[2]- l_slower_ma>0 && Low[1]-l_slower_ma>=0){
          strTrend = "long";
      }
      if(Close[2]- l_slower_ma<0 && High[1]-l_slower_ma<=0){
          strTrend = "short";
      }
   }
   
   /*
   if(l_fast_ma>l_slower_ma && l_slow_ma>l_slower_ma && l_fast_ma>l_slow_ma){
      strTrend = "long";
   }else if(l_fast_ma<l_slower_ma && l_slow_ma<l_slower_ma && l_fast_ma<l_slow_ma){
      strTrend = "short";
   }else{
      strTrend = "";
   }
   */
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
   //setZigzagText(limit);
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
   setZigzagLine();
   
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

void setZigzagLine(){
   ObjectsDeleteAll(0, OBJ_HLINE);
   double hPrice,lPrice;
   for(int i=0;i<3;i++){
      hPrice = arrZigzagHigh[i];
      lPrice = arrZigzagLow[i];
      ObjectCreate("hline_"+i,OBJ_HLINE,0,0,hPrice);
      ObjectSet("hline_"+i,OBJPROP_COLOR,Yellow);
      ObjectCreate("lline_"+i,OBJ_HLINE,0,0,lPrice);
      ObjectSet("lline_"+i,OBJPROP_COLOR,White);
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
    //strComment += "\n高点前三："+arrZigzagHigh[0]+"|"+arrZigzagHigh[1]+"|"+arrZigzagHigh[2];
    //strComment += "\n低点前三："+arrZigzagLow[0]+"|"+arrZigzagLow[1]+"|"+arrZigzagLow[2];
    
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
          Print("------close all buy:ticket="+ord_arr[j]+";result:"+OrderDeleted);
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
          Print("------close all sell:ticket="+ord_arr[j]+";result:"+OrderDeleted);
       }
    }
}

double getLots(){
   if(lots != 0){
      return lots;
   }
   double equity = AccountEquity();
   if(equity <= 150){
      return 0.01;
   }else if(equity > 150 && equity <= 250){
      return 0.02;
   }else if(equity > 250 && equity <= 400){
      return 0.03;
   }else if(equity > 400 && equity <= 600){
      return 0.04;
   }else if(equity > 600 && equity <= 800){
      return 0.05;
   }else if(equity > 800 && equity <= 1200){
      return 0.06;
   }else if(equity > 1200 && equity <= 1600){
      return 0.07;
   }else if(equity > 1600 && equity <= 2000){
      return 0.08;
   }else if(equity > 2000 && equity <= 2600){
      return 0.09;
   }else if(equity > 2600 && equity <= 3200){
      return 0.1;
   }else if(equity > 3200 && equity <= 3800){
      return 0.12;
   }else if(equity > 3800 && equity <= 4400){
      return 0.15;
   }else if(equity > 4400 && equity <= 5000){
      return 0.18;
   }else if(equity > 5000 && equity <= 5800){
      return 0.2;
   }else if(equity > 5800 && equity <= 6800){
      return 0.25;
   }else if(equity > 6800 && equity <= 8000){
      return 0.3;
   }else if(equity > 8000 && equity <= 9000){
      return 0.35;
   }else if(equity > 9000 && equity <= 10000){
      return 0.4;
   }else if(equity > 10000 && equity <= 12000){
      return 0.5;
   }else if(equity > 12000 && equity <= 14000){
      return 0.6;
   }else if(equity > 14000 && equity <= 16000){
      return 0.7;
   }else if(equity > 16000 && equity <= 20000){
      return 0.8;
   }else if(equity > 20000 && equity <= 28000){
      return 0.9;
   }else if(equity > 28000){
      return 1;
   }
}








//移动止损
void trailStop(){
   if(!tradeOver && tradeType != "none"){
      double x,y,newSL,newSLy;
      double openPrice,myStopLoss;
      for (int i=0; i<OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {     
         if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol()){
            if(OrderComment() == "FirstBuy"){
		         openPrice = OrderOpenPrice();
		         myStopLoss = OrderStopLoss();
               if(myStopLoss<openPrice && Bid - openPrice > 500*sx*Point){
                  //设置平保
                  newSL = openPrice+50*sx*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  Print("---firstBuy设置平保："+OrderTicket());
               }
               if(Bid - openPrice > 800*sx*Point && myStopLoss>openPrice && myStopLoss-openPrice<200*sx*Point){
                  newSL = openPrice+400*sx*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  Print("---firstBuy设置盈利锁定40："+OrderTicket());
               }
            }
            if(OrderComment() == "FirstSell"){
	            openPrice = OrderOpenPrice();
	            myStopLoss = OrderStopLoss();
               if((myStopLoss>openPrice || myStopLoss ==0) && openPrice-Ask > 500*sx*Point){
                  //设置平保
                  newSL = openPrice - 50*sx*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  Print("---firstSell设置平保："+OrderTicket());
               }
               if(openPrice-Ask > 800*sx*Point && myStopLoss<openPrice && openPrice-myStopLoss<200*sx*Point){
                  newSL = openPrice - 400*sx*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  Print("---firstSell设置盈利锁定40："+OrderTicket());
               }
            }
         }
      }
     }
   }
}

void orderMgr(){
   if(tradeType == "buy"){
      if(isSuperMgr && h1_ma1-Ask>120*sx*Point && iHigh(NULL,slowerFrame,0)-h1_ma1>=180*sx*Point){
         isSuperMgr = false;
         close_buy_orders();
         Print("---orderMgr:超级突破，止损保护 close buy");
      }
   }
   if(tradeType == "sell"){
      if(isSuperMgr && Bid - h1_ma1>120*sx*Point && h1_ma1 - iLow(NULL,slowerFrame,0)>=180*sx*Point){
         isSuperMgr = false;
         close_sell_orders();
         Print("---orderMgr:超级突破，止损保护 close sell");
      }
   
   }
   
}