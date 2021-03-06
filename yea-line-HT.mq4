//+------------------------------------------------------------------+

//|                                                       yea-line-HT.mq4 |

//|                                                       xiaoxin003 |

//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+

extern string YW001 = "yea-line-HT";
extern int      _SL_Pips        = 300;
extern int      _TP_Pips        = 1200;
extern double   Lots            = 0.01;
extern int      Max_Open_Orders = 5;
extern string   strMin_Distance_pips = "加仓间隔点数";
extern int      _Min_Distance_pips   = 200;
extern string   strProfitLock_pips   = "赚多少点开始平保";
extern int      _profitLock_pips     = 300;
extern string   strisTrailStop       = "是否移动止损";
extern bool     isTrailStop          = true;
extern int      _TrailStop_pips      = 300;
extern int      _TrailStep_pips      = 100;
extern string   strentry_pips        = "提前入场点数默认3点";
extern int      _entry_pips          = 30;
extern string   strbreakout_pips     = "突破点数";
extern int      _breakout_pips       = 200;
int    _max_spread = 200;  //点差大于这个数禁止交易
int    _PL_pips    = 30;   //平保位于价格上点数

int MagicNumber = 198703;
int sx;
int SL_Pips,
    TP_Pips,
    Min_Distance_pips,
    profitLock_pips,
    TrailStop_pips,
    TrailStep_pips,
    max_spread,
    PL_pips,
    entry_pips,
    breakout_pips;
string strComment = "";
double arrHTline[];  //水平线和趋势线在当前柱体的价位，支持或阻力位
string arrHTlineName[];  //对应趋势值的线条名称
double arrHTlineSort[];
int    htIndex = 0; //线条数组索引，必须是全局，所有种类线条是放到一个数组的

int    NewOrder=0;
int    oper_max_tries = 20,tries=0;
double sl_price=0,tp_price=0;
datetime prev_order_time=0;
int ord_arr[20];
bool OrderSelected=false,OrderDeleted=false;

void myInit(){
   sx = 1;
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   SL_Pips           = _SL_Pips*sx;
   TP_Pips           = _TP_Pips*sx;
   Min_Distance_pips = _Min_Distance_pips*sx;
   profitLock_pips   = _profitLock_pips*sx;
   TrailStop_pips    = _TrailStop_pips*sx;
   TrailStep_pips    = _TrailStep_pips*sx;
   max_spread        = _max_spread*sx;
   PL_pips           = _PL_pips*sx;
   entry_pips        = _entry_pips*sx;
   breakout_pips     = _breakout_pips*sx;
}

void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认Hline和Tline";
    strComment += "\n买入价："+Bid;
    strComment += "\n卖出价："+Ask;
    strComment += "\n账户余额："+AccountBalance();
    strComment += "\n账户净值："+AccountEquity();
    strComment += "\n可用保证金："+AccountFreeMargin();
    strComment += "\n杠杆："+AccountLeverage();
    strComment += "\n点差："+getAsk_Bid()/Point;
    strComment += "\n今天周几："+DayOfWeek();
    strComment += "\n当前时间："+Hour()+":"+Minute();
    
}
/*

@@ 获取所有水平线 目前支持5根 命名为Hlinex

*/
void getHline(){
   double hVal = 0;
   for(int i=1;i<=5;i++){
      if(ObjectFind("Hline"+i) != -1){
         if(isBlackLine("Hline"+i)){
            //反复穿越的线
             strComment += ("\nHline"+i+" --> 黑名单");
             continue;
         }
         hVal = ObjectGet("Hline"+i, OBJPROP_PRICE1);
         ArrayResize(arrHTline,ArraySize(arrHTline)+1);
         hVal = NormalizeDouble(hVal,Digits);
         arrHTline[htIndex] = hVal;
         ArrayResize(arrHTlineName,ArraySize(arrHTlineName)+1);
         arrHTlineName[htIndex] = "Hline"+i;
         htIndex++;
         strComment += ("\nHline"+i+"当前价格为："+hVal);
      }else{
      }
   }
}
/*

@@ 获取所有趋势线 目前支持5根 命名为Tlinex

*/
void getTline(){
   double hVal = 0;
   int index = 0;
   for(int i=1;i<=5;i++){
      if(ObjectFind("Tline"+i) != -1){
         if(isBlackLine("Tline"+i)){
            //反复穿越的线
             strComment += ("\nTline"+i+" --> 黑名单");
             continue;
         }
         //strComment += ("\n已找到自划线Tline"+i);
         hVal = ObjectGetValueByShift("Tline"+i,0);
         ArrayResize(arrHTline,ArraySize(arrHTline)+1);
         hVal = NormalizeDouble(hVal,Digits);
         arrHTline[htIndex] = hVal;
         ArrayResize(arrHTlineName,ArraySize(arrHTlineName)+1);
         arrHTlineName[htIndex] = "Tline"+i;
         htIndex++;
         strComment += ("\nTline"+i+"当前价格为："+hVal);
      }else{
      }
   }
}
//根据线条名称获取，当时第几个柱子的价格
double getPriceByLineName(string name, int shift){
   string h = StringSubstr(name,0,1);
   double hVal;
   if(h == "T"){
      hVal = ObjectGetValueByShift(name,shift);
   }
   if(h == "H"){
      hVal = ObjectGet(name, OBJPROP_PRICE1);
   }
   hVal = NormalizeDouble(hVal,Digits);
   return hVal;
}
//线条反复穿越则失效，黑名单机制
bool isBlackLine(string strLineName){
     int bars = iBars(Symbol(),0);
     if(bars >150){bars = 150;}
     double linePrice;
     int count = 0;
     for(int i=1;i<=bars;i++){
        linePrice = getPriceByLineName(strLineName,i);
        if(linePrice >0){
         if((High[i]-Low[i] < 200*sx*Point && (High[i]-linePrice>=30*sx*Point) && (linePrice - Low[i]>=30*sx*Point)){
            //strComment += "\n"+strLineName+"-> shift:"+i+"; high:"+High[i]+"; low:"+Low[i]+"; linePrice:"+linePrice;
            count++;
         }
        }
        if(count >=5){
         break;
        }
     }
     strComment += "\n"+strLineName+"-> 反复穿越次数："+count;
     if(count>= 5){
      return true;
     }
     else
     {
      return false;
     }
}
void getLine(){
   ArrayResize(arrHTline,0);
   ArrayResize(arrHTlineSort,0);
   ArrayResize(arrHTlineName,0);
   htIndex = 0;
   //获取黑名单
   getHline();
   getTline();
   ArrayCopy(arrHTlineSort,arrHTline);
   if(ArraySize(arrHTlineSort) >1){
      ArraySort(arrHTlineSort,WHOLE_ARRAY,0,MODE_ASCEND);
   }
}
//根据价格获取一个线条名称，如果是多个则用,符号分隔
string getLineNameByPrice(double price){
   string name = "";
   for(int i=0;i<ArraySize(arrHTline);i++){
      if(DoubleToStr(arrHTline[i],5) == DoubleToStr(price,5)){
         if(name == ""){
            name = arrHTlineName[i];
         
         }else{
            name += ","+arrHTlineName[i];
         }
      }
   }
   return name;
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
int market_buy_order(string memo)
{
   NewOrder=0;
   tries=0;
   if(SL_Pips==0){
	sl_price = 0;
   }else{
	sl_price = Bid - SL_Pips*Point;
   }
   if(TP_Pips==0){
	tp_price = 0;
   }else{
	tp_price = Ask + TP_Pips*Point;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      NewOrder=OrderSend(Symbol(),OP_BUY,Lots,Ask,5,sl_price,tp_price,memo,Magic_Number,0,Blue);            
      tries = tries+1;
   }
   if(NewOrder>0) prev_order_time = TimeCurrent();
   return(NewOrder);
}
int market_sell_order(string memo)
{
   NewOrder=0;
   tries=0;
   if(SL_Pips==0){
	sl_price = 0;
   }else{
	sl_price = Ask+SL_Pips*Point;
   }
   if(TP_Pips==0){
	tp_price = 0;
   }else{
	tp_price = Bid-TP_Pips*Point;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      NewOrder = OrderSend(Symbol(),OP_SELL,Lots,Bid,5,sl_price,tp_price,memo,Magic_Number,0,Red);            
      tries = tries+1;
   }
   if(NewOrder>0) prev_order_time = TimeCurrent();
   return(NewOrder);
}
void close_sell_orders()
{ 
   int k=-1;
   for(int j=0;j<20;j++) ord_arr[j]=0;
   
   int ot = OrdersTotal();
   for(j=0;j<ot;j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number)
      {   
         if(OrderType()==OP_SELL)   
         {  k = k + 1; 
            ord_arr[k]=OrderTicket();
         }
      }     
    }
    for(j=0;j<=k;j++)
    {  OrderDeleted=false;
       tries=0;
       while(!OrderDeleted && tries<oper_max_tries)
       {
          OrderDeleted=OrderClose(ord_arr[j],OrderLots(),Ask,5,Red);
          tries=tries+1;
       }
    }
}

void close_buy_orders()
{ int k=-1;
   for(int j=0;j<20;j++) ord_arr[j]=0;
   
   int ot = OrdersTotal();
   for(j=0;j<ot;j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number)
      {   
         if(OrderType()==OP_BUY)   
         {  k = k + 1; 
            ord_arr[k]=OrderTicket();
         }
      }     
    }
    for(j=0;j<=k;j++)
    {  OrderDeleted=false;
       tries=0;
       while(!OrderDeleted && tries<oper_max_tries)
       {
          OrderDeleted=OrderClose(ord_arr[j],OrderLots(),Bid,5,Red);
          tries=tries+1;
       }
    }
}
void doit(){
   getLine();
   string lineName = "";
   double q1,q2,q3;
   for(int i=0;i<ArraySize(arrHTlineSort);i++){
      if(Ask>Low[0] && Low[0]-arrHTlineSort[i]<entry_pips*Point && Low[0]-arrHTlineSort[i] >0){
         //买点
	 if((TimeCurrent()-prev_order_time)/60>=4*Period() && total_orders()<Max_Open_Orders){
	    lineName = getLineNameByPrice(arrHTlineSort[i]);
            q1 = getPriceByLineName(lineName,1);
            q2 = getPriceByLineName(lineName,2);
            q3 = getPriceByLineName(lineName,3);
	    if(Close[1]>q1 && Close[2]>q2 && Close[3]>q3){
	       close_sell_orders();
	       market_buy_order(lineName+" BUY");
	    }
	 }
      }
      if(Ask<High[0] && arrHTlineSort[i] - High[0] <entry_pips*Point && arrHTlineSort[i] - High[0] >0){
         //卖点
	 if((TimeCurrent()-prev_order_time)/60>=4*Period() && total_orders()<Max_Open_Orders){
	    lineName = getLineNameByPrice(arrHTlineSort[i]);
            q1 = getPriceByLineName(lineName,1);
            q2 = getPriceByLineName(lineName,2);
            q3 = getPriceByLineName(lineName,3);
	    if(Close[1]<q1 && Close[2]<q2 && Close[3]<q3){
	       close_buy_orders();
	       market_sell_order(lineName+" SELL");
	    }
	 }
      }

   }
}

int start(){
   getTradeInfo();
   myInit();
   if(checkAccountTrade()){
      doit();  //主要交易
   }
   trailStop();
   Comment(strComment);
   return 0;
}

//点差检测
double getAsk_Bid(){
   return (Ask - Bid);
}

//检测账户开单条件
bool checkAccountTrade(){
   if(AccountEquity() <=1 || AccountFreeMargin()<=1 || getAsk_Bid() > max_spread*Point){
	strComment += "\n账户净值或保证金不足 || 点差>"+max_spread+"，风险过大！";
	return false;
   }else{
	return true;
   }
}

void trailStop(){
   if(isTrailStop){
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
               if(Bid - openPrice > TrailStop_pips*Point){
                  //按比例移动止损
                  x = (Bid - openPrice)/(TrailStop_pips*Point);
                  newSL = (openPrice-SL_Pips*Point)+x*TrailStep_pips*Point;
                  if(myStopLoss + TrailStep_pips*Point < newSL){
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
               if(openPrice - Ask > TrailStop_pips*Point){
                  y = (openPrice - Ask)/(TrailStop_pips*Point);
                  newSLy = (openPrice+SL_Pips*Point)-y*TrailStep_pips*Point;
                  if(myStopLoss-TrailStep_pips*Point>newSLy){
                     OrderModify(OrderTicket(),openPrice,newSLy, OrderTakeProfit(), 0);
                  }
               }
            }
         }
      }
     }
   }
}