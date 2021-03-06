//+------------------------------------------------------------------+

//|                                                             黑豹x|
//| 通过时间判断经过柱子数量：
//   if((TimeCurrent()-prev_order_time_buy)/60<intZhuziNums*Period()){}
//+------------------------------------------------------------------+

extern string   strVer            = "黑豹x1";
extern int      Magic_Number_First    = 20160803;    //趋势第一单
extern int      Magic_Number_Nishi    = 2016080301;  //逆势单
extern int      Magic_Number_MaFast   = 2016080302;  //SR MA fast
extern int      Magic_Number_MaSlow   = 2016080303;  //SR MA slow
extern int      Magic_Number_MaSlower = 2016080304;  //SR MA slower

extern int      First_Zhuzi_nums     = 500;   //趋势第一单最大平仓柱子数
extern int      Nishi_Zhuzi_nums     = 15;
extern int      MaFast_Zhuzi_nums    = 60;
extern int      MaSlow_Zhuzi_nums    = 50;
extern int      MaSlower_Zhuzi_nums  = 30;

extern int      TP_First             = 3000;   //止盈点数300点
extern int      TP_Nishi             = 500;
extern int      TP_MaFast            = 200;
extern int      TP_MaSlow            = 400;
extern int      TP_MaSlower          = 500;

extern int      fastMa            = 120;
extern int      slowMa            = 190;
extern int      slowerMa          = 300;
extern int      SL_Pips           = 300;
extern int      TP_Pips           = 0;
extern double   lots                   = 0;
extern int      Max_Open_Orders        = 4;
extern int      maMethod               = 0;           //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern string   strMemo1               = "fastMa上下多少点可以开反向单";   
extern int      fastMa_distence_Pips   = 0;

string          tradeType         = "none";      //buy sell none
string          strComment        = "";
datetime        prev_order_time_buy   = 1262278861;
datetime        prev_order_time_sell  = 1262278861;
double          last_buy_price=0;
double          last_sell_price=0;

int             max_spread     = 300;         //最大可交易点差
int             intZhuziNums   = 0;           //开单间隔柱子数
int             slippage       = 5;           //最大滑点数
int             sx  = 1;                      //不同货币点值处理
double          Spread;                       //订单关闭用的点差范围
int             firstNum;                      //趋势改变的柱子数

double          fast_ma1,slow_ma1,slower_ma1;
datetime        prev_open_time    = 0;
int             stage             = 0;           //记录当前趋势下行驶了多少根柱子


double max_open_order_buy,max_open_order_sell;
double last_nishi_buy_price = 999999;
double last_nishi_sell_price = 0;



int init(){
   Spread = NormalizeDouble(MarketInfo(Symbol(), MODE_SPREAD),Digits)*Point;   //计算货币当前点差
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   
   TP_Pips              = TP_Pips*sx;
   max_spread           = max_spread*sx;
   SL_Pips              = SL_Pips*sx;
   fastMa_distence_Pips = fastMa_distence_Pips*sx;
   TP_First             = TP_First*sx;
   TP_Nishi             = TP_Nishi*sx;
   TP_MaFast            = TP_MaFast*sx;
   TP_MaSlow            = TP_MaSlow*sx;
   TP_MaSlower          = TP_MaSlower*sx;
   
   max_open_order_buy   = Max_Open_Orders*0.5;
   max_open_order_sell  = Max_Open_Orders*0.5;
   intZhuziNums = 10;
   firstNum = 40;
   if(fastMa_distence_Pips == 0){
      fastMa_distence_Pips = 1200*sx;
   }
   Print("趋势逆转柱子数量："+firstNum);
   Print("开单间隔柱子数量："+intZhuziNums);
   Print("逆势开单点数："+fastMa_distence_Pips);
   //Print("止盈点数："+TP_Pips);
   return 0;
}

int start(){
   
   if(prev_open_time != Time[0]){
      prev_open_time = Time[0];
      fast_ma1   = iMA(Symbol(),0,fastMa,0,maMethod,PRICE_CLOSE,1);
      slow_ma1   = iMA(Symbol(),0,slowMa,0,maMethod,PRICE_CLOSE,1);
      slower_ma1 = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
      
      if(first_buy_check()){
         if(tradeType == "none"){
            stage = 1;
            First_Buy();
         }
         if(tradeType == "sell"){
            close_sell_Profit_orders();
            stage = 1;
            last_nishi_buy_price = 999999;
            last_nishi_sell_price = 0;       
            First_Buy();
         }
         tradeType = "buy";
      }
      if(first_sell_check()){
         if(tradeType == "none"){
            stage = 1;
            First_Sell();
         }
         if(tradeType == "buy"){
            close_buy_Profit_orders();
            stage = 1;
            last_nishi_buy_price = 999999;
            last_nishi_sell_price = 0;
            First_Sell();
         }
         tradeType = "sell";
      }
      stage += 1;
      Order_Timeover_Deal();
   }
   
   tradeRun();
   set_stoploss();
   ///////////////////////////////////////////////////
   
   getTradeInfo();
   Comment(strComment);
   return 0;
}

void tradeRun(){
   if(tradeType == "buy"){
      if(nishi_sell_check()){
         order_sell("nishi");
      }else if(SR_buy_check("slowerma")){
         order_buy("slowerma");
      }else if(SR_buy_check("slowma")){
         order_buy("slowma");
      }else if(SR_buy_check("fastma")){
         order_buy("fastma");
      }
   }
   if(tradeType == "sell"){
      if(nishi_buy_check()){
         order_buy("nishi");
      }else if(SR_sell_check("slowerma")){
         order_sell("slowerma");
      }else if(SR_sell_check("slowma")){
         order_sell("slowma");
      }else if(SR_sell_check("fastma")){
         order_sell("fastma");
      }
   }   
}

bool first_buy_check(){
  
   double tmpMa;
   for(int i=1;i<firstNum;i++){
      tmpMa = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,i);
      if(Close[i] - tmpMa<0){
         return false;
      }
   }
   return true;
}
bool first_sell_check(){
   double tmpMa;
   for(int i=1;i<firstNum;i++){
      tmpMa = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,i);
      if(tmpMa - Close[i]<0){
         return false;
      }
   }
   return true;
}


int market_buy_order(double sl, double tp, double Lots, string memo)
{
   if(AccountLeverage()<400){return 0;}
   if(!checkAccountTrade()){return 0;}
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
   int magic = Magic_Number_First;
   if(memo == "first"){
      magic = Magic_Number_First;
   }else if(memo == "nishi"){
      magic = Magic_Number_Nishi;
   }else if(memo == "slowerma"){
      magic = Magic_Number_MaSlower;
   }else if(memo == "slowma"){
      magic = Magic_Number_MaSlow;
   }else if(memo == "fastma"){
      magic = Magic_Number_MaFast;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      Print("-------------buy:----sl:"+sl_price+";tp:"+tp_price);
      NewOrder = OrderSend(Symbol(),OP_BUY,Lots,Ask,slippage,sl_price,tp_price,memo,magic,0,Blue);            
      tries = tries+1;
   }
   Print("-------------buy result:"+NewOrder);
   if(NewOrder>0){
      last_buy_price = Ask;
      if(memo == "nishi"){
         last_nishi_buy_price = Ask;
      }
      prev_order_time_buy = TimeCurrent();
   }
   return(NewOrder);
}

int market_sell_order(double sl, double tp, double Lots, string memo)
{
   if(AccountLeverage()<400){return 0;}
   if(!checkAccountTrade()){return 0;}
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
   int magic = Magic_Number_First;
   if(memo == "first"){
      magic = Magic_Number_First;
   }else if(memo == "nishi"){
      magic = Magic_Number_Nishi;
   }else if(memo == "slowerma"){
      magic = Magic_Number_MaSlower;
   }else if(memo == "slowma"){
      magic = Magic_Number_MaSlow;
   }else if(memo == "fastma"){
      magic = Magic_Number_MaFast;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      Print("-------------sell:----bid:"+Bid+";sl:"+sl_price+";tp:"+tp_price);
      RefreshRates();
      NewOrder = OrderSend(Symbol(),OP_SELL,Lots,Bid,slippage,sl_price,tp_price,memo,magic,0,White);            
      tries = tries+1;
   }
   Print("-------------sell result:"+NewOrder);
   if(NewOrder>0){
      if(memo == "nishi"){
         last_nishi_sell_price = Bid;
      }
      last_sell_price = Bid;
      prev_order_time_sell = TimeCurrent();
   }
   return(NewOrder);
}

int order_buy(string type){
   if(MathAbs(Ask-last_buy_price) < 70*sx*Point){
      //防止磨线
      return 0;
   }
   int realTP = TP_Pips;
   if(type == "nishi"){
      realTP = TP_Nishi;
   }else if(type == "slowerma"){
      realTP = TP_MaSlower;
   }else if(type == "slowma"){
      realTP = TP_MaSlow;
   }else if(type == "fastma"){
      realTP = TP_MaFast;
   }
   double realLots = getLots();
   int NewOrder = 0;
   NewOrder = market_buy_order(SL_Pips, realTP, realLots, type);
   if(NewOrder >0){
      return NewOrder;
   }
   return 0;
}

int order_sell(string type){
   if(MathAbs(Bid-last_sell_price) < 70*sx*Point){
      //防止磨线
      return 0;
   }
   int realTP = TP_Pips;
   if(type == "nishi"){
      realTP = TP_Nishi;
   }else if(type == "slowerma"){
      realTP = TP_MaSlower;
   }else if(type == "slowma"){
      realTP = TP_MaSlow;
   }else if(type == "fastma"){
      realTP = TP_MaFast;
   }
   double realLots = getLots();
   int NewOrder = 0;
   NewOrder = market_sell_order(SL_Pips, realTP, realLots, type);
   if(NewOrder >0){
       return NewOrder;
   }
   return 0;
}


//逆势加单检测
bool nishi_buy_check(){
   if(Close[2] - Open[2]>0 || High[2]-Low[2]<350*sx*Point || Close[1] - Open[1]<=0){
      return false;
   }
   if((TimeCurrent()-prev_order_time_buy)/60<intZhuziNums*3*Period()){
      //Print("--距离上次不足5根");
      return false;
   }
   if(total_orders_buy() >= max_open_order_buy){
      //Print("--已开单最大值");
      return false;
   }
   if(last_nishi_buy_price - Ask<500*sx*Point){
      return false;
   }
   if(Ask>Low[0] && fast_ma1<slower_ma1 && slow_ma1<slower_ma1 && fast_ma1-Bid>fastMa_distence_Pips*Point){
      //Print("--逆势buy_check is true!!");
      return true;
   }
   return false;

}

bool nishi_sell_check(){
   if(Close[2] - Open[2]<0 || High[2]-Low[2]<350*sx*Point || Close[1] - Open[1]>0){
      return false;
   }
   if((TimeCurrent()-prev_order_time_sell)/60<intZhuziNums*3*Period()){
      //Print("--距离上次不足5根");
      return false;
   }
   if(total_orders_sell() >= max_open_order_sell){
      //Print("--已开单最大值");
      return false;
   }
   if(Bid - last_nishi_sell_price<500*sx*Point){
      return false;
   }
   if(High[0]>Ask && fast_ma1>slower_ma1 && slow_ma1>slower_ma1 && Ask - fast_ma1>fastMa_distence_Pips*Point){
      //Print("--逆势sell_check is true!!");
      return true;
   }
   return false;
   
}

//趋势第一个买单
int First_Buy(){
   if(total_orders_buy() >= max_open_order_buy){
      return 0;
   }
   int NewOrder = 0;
   if(Ask - slower_ma1 >0 && Ask - slower_ma1<200*sx*Point){
      double realLots = getLots();
      NewOrder = market_buy_order(SL_Pips, TP_First, realLots, "first");
      if(NewOrder >0){
         return NewOrder;
      }
      
   }
   return 0;
}

//趋势第一个卖单
int First_Sell(){
   if(total_orders_buy() >= max_open_order_sell){
      return 0;
   }
   int NewOrder = 0;
   if(slower_ma1 - Ask >0 && slower_ma1 - Ask<200*sx*Point){
      double realLots = getLots();
      NewOrder = market_sell_order(SL_Pips, TP_First, realLots, "first");
      if(NewOrder >0){
         return NewOrder;
      }
      
   }
   return 0;
}

bool SR_buy_check(string type){
   
   if(total_orders_buy() >= max_open_order_buy){
      return false;
   }
   if((TimeCurrent()-prev_order_time_buy)/60<intZhuziNums*Period()){
         return false;
   }
   if(type == "slowerma"){
      if(Low[0]<Bid && Close[2]-slower_ma1>0 && Ask - slower_ma1 >0 && Ask-slower_ma1<=30*sx*Point){
         return true;
      }
   }else if(type == "slowma"){
      if(Low[0]<Bid && Close[2]-slow_ma1>0 && Ask - slow_ma1 >0 && Ask - slow_ma1<=30*sx*Point){
         return true;
      }
   }else if(type == "fastma"){
      if(Low[0]<Bid && Close[2]-fast_ma1>0 && Ask - fast_ma1 >0 && Ask - fast_ma1<=30*sx*Point){
         return true;
      }
   }
   return false;
}

bool SR_sell_check(string type){
   if(total_orders_sell() >= max_open_order_sell){
      return false;
   }
   if((TimeCurrent()-prev_order_time_sell)/60<intZhuziNums*Period()){
      return false;
   }
   if(type == "slowerma"){
      if(High[0] > Ask && slower_ma1-Close[2]>0 && slower_ma1 - Bid >0 && slower_ma1 - Bid<=30*sx*Point){
         return true;
      }
   }else if(type == "slowma"){
      if(High[0] > Ask && slow_ma1-Close[2]>0 && slow_ma1 - Bid >0 && slow_ma1 - Bid<=30*sx*Point){
         return true;
      }
   }else if(type == "fastma"){
      if(High[0] > Ask && fast_ma1-Close[2]>0 && fast_ma1 - Bid >0 && fast_ma1 - Bid<=30*sx*Point){
         return true;
      }
   }
   return false;
}

void close_Profit_orders(){
   close_buy_Profit_orders();
   close_sell_Profit_orders();
}
void close_buy_Profit_orders()
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
      if(OrderSymbol()==Symbol() && (OrderMagicNumber()==Magic_Number_First || 
                                     OrderMagicNumber()==Magic_Number_MaFast || 
                                     OrderMagicNumber()==Magic_Number_MaSlow || 
                                     OrderMagicNumber()==Magic_Number_MaSlower || 
                                     OrderMagicNumber()==Magic_Number_Nishi))
      {   
         if(OrderType()==OP_BUY && OrderProfit()>0)   
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
          OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Bid,Spread,Red);
          tries=tries+1;
          Print("------close all buy:ticket="+ord_arr[j]+";result:"+OrderDeleted);
       }
    }
}

void close_sell_Profit_orders()
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
      if(OrderSymbol()==Symbol() && (OrderMagicNumber()==Magic_Number_First || 
                                     OrderMagicNumber()==Magic_Number_MaFast || 
                                     OrderMagicNumber()==Magic_Number_MaSlow || 
                                     OrderMagicNumber()==Magic_Number_MaSlower || 
                                     OrderMagicNumber()==Magic_Number_Nishi))
      {   
         if(OrderType()==OP_SELL && OrderProfit()>0)   
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
          OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Ask,Spread,Red);
          tries=tries+1;
          Print("------close all sell:ticket="+ord_arr[j]+";result:"+OrderDeleted);
       }
    }
}

void close_order_byticket(string bs_type, int ticket){
   int tries=0,oper_max_tries=30;
   bool OrderDeleted = false;
   if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)){
       double b_lots = OrderLots();
       while(!OrderDeleted && tries<oper_max_tries)
       {
          if(bs_type == "buy"){
            OrderDeleted=OrderClose(ticket,b_lots,Bid,Spread,Red);
          }
          if(bs_type == "sell"){
            OrderDeleted=OrderClose(ticket,b_lots,Ask,Spread,Red);
          }
          tries=tries+1;
       }
   }
}


double getLots(){
   if(lots != 0){
      return lots;
   }
   double equity = AccountEquity();
   if(equity <= 200){
      return 0.03;
   }else if(equity > 200 && equity <= 400){
      return 0.1;
   }else if(equity > 400 && equity <= 600){
      return 0.2;
   }else if(equity > 600 && equity <= 1000){
      return 0.5;
   }else if(equity > 1000 && equity <= 4000){
      return 1;
   }else if(equity > 4000 && equity <= 6000){
      return 2;
   }else if(equity > 6000 && equity <= 9000){
      return 3;
   }else if(equity > 9000 && equity <= 13000){
      return 4;
   }else if(equity > 13000 && equity <= 16000){
      return 5;
   }else if(equity > 16000 && equity <= 20000){
      return 6;
   }else if(equity > 20000 && equity <= 30000){
      return 7;
   }else if(equity > 30000 && equity <= 40000){
      return 8;
   }else if(equity > 40000 && equity <= 50000){
      return 9;
   }else if(equity > 50000 && equity <= 60000){
      return 10;
   }else if(equity > 60000 && equity <= 70000){
      return 11;
   }else if(equity > 70000 && equity <= 80000){
      return 12;
   }else if(equity > 80000 && equity <= 90000){
      return 13;
   }else if(equity > 90000 && equity <= 100000){
      return 14;
   }else if(equity > 100000 && equity <= 110000){
      return 15;
   }else if(equity > 110000){
      return 16;
   }
}

int total_orders()
{ 
   int tot_orders = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && (OrderMagicNumber()==Magic_Number_First || 
                                     OrderMagicNumber()==Magic_Number_MaFast || 
                                     OrderMagicNumber()==Magic_Number_MaSlow || 
                                     OrderMagicNumber()==Magic_Number_MaSlower || 
                                     OrderMagicNumber()==Magic_Number_Nishi))
      {
         if(OrderType() == OP_BUY){
            tot_orders = tot_orders + 1;
         }else if(OrderType() == OP_SELL){
            tot_orders = tot_orders + 1;
         }
         
      }
   }
   return(tot_orders);
}

int total_orders_buy()
{ 
   int tot_orders = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && (OrderMagicNumber()==Magic_Number_First || 
                                     OrderMagicNumber()==Magic_Number_MaFast || 
                                     OrderMagicNumber()==Magic_Number_MaSlow || 
                                     OrderMagicNumber()==Magic_Number_MaSlower || 
                                     OrderMagicNumber()==Magic_Number_Nishi))
      {
         if(OrderType() == OP_BUY){
            tot_orders = tot_orders + 1;
         }
         
      }
   }
   return(tot_orders);
}

int total_orders_sell()
{ 
   int tot_orders = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && (OrderMagicNumber()==Magic_Number_First || 
                                     OrderMagicNumber()==Magic_Number_MaFast || 
                                     OrderMagicNumber()==Magic_Number_MaSlow || 
                                     OrderMagicNumber()==Magic_Number_MaSlower || 
                                     OrderMagicNumber()==Magic_Number_Nishi))
      {
         if(OrderType() == OP_SELL){
            tot_orders = tot_orders + 1;
         }
         
      }
   }
   return(tot_orders);
}
void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认3条均线值:"+fastMa+"|"+slowMa+"|"+slowerMa;
    //strComment += "\n买入价："+Bid;
    //strComment += "\n卖出价："+Ask;
    strComment += "\n交易方向："+tradeType;
    strComment += "\n账户余额："+AccountBalance();
    strComment += "\n账户净值："+AccountEquity();
    //strComment += "\n可用保证金："+AccountFreeMargin();
    strComment += "\n杠杆："+AccountLeverage();
    //strComment += "\n点差："+getAsk_Bid()/Point;
    //strComment += "\n今天周几："+DayOfWeek();
    //strComment += "\n当前时间："+Hour()+":"+Minute();
    strComment += "\n当前阶段："+stage;
    //strComment += "\n当前zigzagTrendType："+zigzagTrendType;
    
}


//点差检测
double getAsk_Bid(){
   return (Ask - Bid);
}

//检测账户开单条件
bool checkAccountTrade(){
   if(AccountEquity() <=40 || AccountFreeMargin()<=30 || getAsk_Bid() > max_spread*Point){
	strComment += "\n账户净值或保证金不足 || 点差>"+max_spread+"，风险过大！";
	   return false;
   }else{
	   return true;
   }
}

//订单到期关闭
void Order_Timeover_Deal(){
   int k=-1;
   int ord_arr[50];
   double ord_arrlots[50];
   string ord_arrtype[50];
   int tries=0,oper_max_tries=30;
   bool OrderDeleted = false;
   for(int j=0;j<50;j++){
      ord_arr[j]=0;
      ord_arrlots[j] = 0;
      ord_arrtype[j] = "";
   }
   int ot = OrdersTotal();
   bool needClose = false;
   bool isMagic = false;
   for(j=0;j<ot;j++)
   {
      needClose = false;
      isMagic = false;
      double order_Profit_lots = 0;
      double close_Profit_lots = 0;
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol()){
         if(OrderMagicNumber() == Magic_Number_First){
            close_Profit_lots =  800;
            if((TimeCurrent()-OrderOpenTime())/60>=First_Zhuzi_nums*Period()){
               needClose = true;
            }
         }else if(OrderMagicNumber() == Magic_Number_MaFast){
             close_Profit_lots =  200;
             isMagic = true;
             if((TimeCurrent()-OrderOpenTime())/60>=MaFast_Zhuzi_nums*Period()){
                needClose = true;
             }
         }else if(OrderMagicNumber() == Magic_Number_MaSlow){
             close_Profit_lots =  300;
             isMagic = true;
             if((TimeCurrent()-OrderOpenTime())/60>=MaSlow_Zhuzi_nums*Period()){
                needClose = true;
             }
         }else if(OrderMagicNumber() == Magic_Number_MaSlower){
             close_Profit_lots =  50;
             isMagic = true;
             if((TimeCurrent()-OrderOpenTime())/60>=MaSlower_Zhuzi_nums*Period()){
                needClose = true;
             }
         }else if(OrderMagicNumber() == Magic_Number_Nishi){
             close_Profit_lots =  400;
             isMagic = true;
             if((TimeCurrent()-OrderOpenTime())/60>=Nishi_Zhuzi_nums*Period()){
                needClose = true;
             }
         }
         //3根柱子中2个是反方向则关掉
         if((TimeCurrent()-OrderOpenTime())/60>=3*Period() && (TimeCurrent()-OrderOpenTime())/60<4*Period()){
            //逆势如果3根就达到止盈的一半则关闭
            if(OrderMagicNumber() == Magic_Number_Nishi){
              if(OrderType()==OP_BUY){
                  order_Profit_lots = (Bid - OrderOpenPrice())/Point/sx;
                 // Print("---"+OrderTicket()+"---nishi buy order profit losts="+order_Profit_lots+"; bid="+Bid+";OrderOpenPrice:"+OrderOpenPrice()+";");
               }else if(OrderType()==OP_SELL){
                  order_Profit_lots = (OrderOpenPrice() -Ask)/Point/sx;
                 // Print("---"+OrderTicket()+"---nishi sell order profit losts="+order_Profit_lots+"; ask="+Ask+";OrderOpenPrice:"+OrderOpenPrice()+";");
               }
               if(order_Profit_lots>=200){
                  needClose = true;
                  Print("--#"+OrderTicket()+"--逆势单3根盈利大于20点，关闭");
               }
            }
            
            //过3根去掉止损
            OrderModify(OrderTicket(),OrderOpenPrice(),0, OrderTakeProfit(), 0);
            if(isMagic && OrderProfit()<0){
               int fan_nums = 0;
               if(OrderType()==OP_BUY){
                  if(Close[3]-Open[3]<0)fan_nums++;
                  if(Close[2]-Open[2]<0)fan_nums++;
                  if(Close[1]-Open[1]<0)fan_nums++;
               }else if(OrderType()==OP_SELL){
                  if(Close[3]-Open[3]>0)fan_nums++;
                  if(Close[2]-Open[2]>0)fan_nums++;
                  if(Close[1]-Open[1]>0)fan_nums++;
                  
               }
               if(fan_nums>=2){
                  needClose = true;
                  Print("--#"+OrderTicket()+"--3根中有大于等于2根是反方向，需要关闭");
               }
            }
         }
         /*
         if(!needClose){
            if(OrderType()==OP_BUY){
               order_Profit_lots = (Bid - OrderOpenPrice())/Point/sx;
               Print("---"+OrderTicket()+"---buy order profit losts="+order_Profit_lots+"; bid="+Bid+";OrderOpenPrice:"+OrderOpenPrice()+";");
            }else if(OrderType()==OP_SELL){
               order_Profit_lots = (OrderOpenPrice() -Ask)/Point/sx;
               Print("---"+OrderTicket()+"---sell order profit losts="+order_Profit_lots+"; ask="+Ask+";OrderOpenPrice:"+OrderOpenPrice()+";");
            }
            if(order_Profit_lots >= close_Profit_lots){
              // needClose = true;
            }
         }
         */
      }
      if(needClose){
         k = k + 1; 
         ord_arr[k] = OrderTicket();
         ord_arrlots[k] = OrderLots();
         if(OrderType()==OP_BUY) ord_arrtype[k] = "buy";
         if(OrderType()==OP_SELL) ord_arrtype[k] = "sell";  
      } 
    }
    for(j=0;j<=k;j++)
    {  
       OrderDeleted = false;
       tries = 0;
       while(!OrderDeleted && tries < oper_max_tries)
       {  if(ord_arrtype[j] == "buy"){
             OrderDeleted = OrderClose(ord_arr[j],ord_arrlots[j],Bid,Spread,Red);
          }
          if(ord_arrtype[j] == "sell"){
             OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Ask,Spread,Red);
          }
          tries=tries+1;
          Print("------close buy:ticket="+ord_arr[j]+";result:"+OrderDeleted);
       }
    }
}

void set_stoploss(){
   
   if(tradeType == "buy" && slower_ma1-Bid>=100*sx*Point){
      set_stoploss_l("buy");
   }
   else if(tradeType == "sell" && Ask - slower_ma1>=100*sx*Point){
      set_stoploss_l("sell");
   }
}

void set_stoploss_l(string type){
   double myStopLoss=0;
   double newSL=0;
    for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && (OrderMagicNumber()==Magic_Number_First || 
                                     OrderMagicNumber()==Magic_Number_MaFast || 
                                     OrderMagicNumber()==Magic_Number_MaSlow || 
                                     OrderMagicNumber()==Magic_Number_MaSlower || 
                                     OrderMagicNumber()==Magic_Number_Nishi))
      {
         if(type== "buy" && OrderType() == OP_BUY){
            myStopLoss = OrderStopLoss();
            if(myStopLoss<=0){
               newSL = Bid-(150*Point);
               OrderModify(OrderTicket(),OrderOpenPrice(),newSL, OrderTakeProfit(), 0);
            }
         }
         if(type== "sell" && OrderType() == OP_SELL){
            myStopLoss = OrderStopLoss();
            if(myStopLoss<=0){
               newSL = Ask+(150*Point);
               OrderModify(OrderTicket(),OrderOpenPrice(),newSL, OrderTakeProfit(), 0);
            }
         }
         
      }
   }
}