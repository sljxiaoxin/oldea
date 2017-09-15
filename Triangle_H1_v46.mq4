//+------------------------------------------------------------------+
//|                                              Triangle_H1_v46.mq4 |
//|    ATTENTION!                                                    |
//|    Do NOT use "Chuvashov's Triangle" experimental Expert Advisor |
//|    in real trading without improvements!                         |
//|                                                  2011,autor,Gkov |
//|                                                     genkov@bk.ru |
//| some recommendations on improvements can be                      |
//| found on http://Forexmql.narod.ru/news.htm web site page         |
//+------------------------------------------------------------------+
#property link      "http://Forexmql.narod.ru/index.htm" 
#property link      "http://forexparter.ucoz.ru/"
#property link      "http://ForexkovTrade.com"
#property link      "http://Animatyc.narod.ru" 
#property link      "http://Fxkom.narod.ru"

#property link      "genkov@bk.ru  kovgd@ya.ru"
//+------------------------------------------------------------------+
extern double SL_B=200;             
extern double TP_B=200;      
extern double SL_S=200; 
extern double TP_S=200;  
extern double Lots=1.0; 
double TrailingStop=40; 
int Magic;                  // the number should be put in the positions opening block
extern int SlbH,SlbS;       // correction SL_B   ( 0)
extern int SlsH,SlsS;       // correction SL_S   (37)
extern int N=30;            // number of calculated bars 
extern int M= 3;            // initial bar, from which the search for fractals in the loop begins.
int    i,k,g,g1;            // numbers of bars in the loops.
int    Tfnb,Tfns;           // counter of founder fractals: b - upper, s - lower ones.
int    Tf1b,Tf2b,Tf1s,Tf2s; // numbers of fractals for drawing the working line
int    Tf3s,Tf3b;           // numbers of fractals for drawing the channels
double TF1B,TF2B,TF1S,TF2S; // prices of fractals - reference points for drawing the main working line 
double TF3B,TF3S;           // prices of fractals - reference points for drawing the channels
datetime timf1b,timf2b,     // time of the upper fractals
         timf1s,timf2s;     // time of the lower fractals
double RatePriceH,RatePriceS; // price change rate
double PricB[60],PricS[60]; // prices of the upper and lower triangle working lines projections
double RazmerS,RazmerH;     // size of the channel width
double Starting_Price_H;    // initial value for calculating the values of each bar of the upper working line projections
double Starting_Price_S;    // initial value for calculating the values of each bar of the lower working line projections
int    cut_left;            // calculated index of the working lines' intersection point to the left (Apex)
datetime time_Apex,         // estimated actual time of the working line's intersection
         time_starting,     // time of the initial calculation of the working line's projections 
         time_bar_zona,     // actual breakthrough area time
         T_period;          // number of seconds for drawing vertical lines by periods

bool   PatternTch=false;    // "Chuvashov's Triangle" pattern
bool   patternSell=false;   // true "1" or false "0" value.
bool   patternBuy=false;    // true "1" or false "0".
double VlFl_L;              // Min value of the nearest lower fractal on the downtrend
double VlFl_H;              // Max value of the nearest upper fractal on the uptrend
datetime tim1_L;            // Time of the nearest lower fractal following the downtrend ?
datetime timL1_H;           // Time of the nearest upper fractal following the uptrend ?
double TP_Modific_B;        // New TakeProfit value.
int    Md,MdL;              // counter of the number of modifications
double TP_Modific_S;        // New TakeProfit value
bool   Open_chenel=false;   // enable/disable opening positions
double P_Tria;              // price of the triangle's third angle

// ---------------------------------------------------------------------+
  void Create_Tr_H() // drawing the channel's upper line by High fractals
   {
   ObjectDelete("Tr_B1");
   ObjectCreate("Tr_B1",OBJ_TREND,0,timf2b,TF2B,timf1b,TF1B); 
   ObjectSet("Tr_B1",OBJPROP_COLOR,Lime);                       // color
   ObjectSet("Tr_B1",OBJPROP_WIDTH,1);                      // thin line
   ObjectSet("Tr_B1",OBJPROP_STYLE,STYLE_SOLID);                // solid
   }
// --------------------------------------------------------------------+
  void Create_Tr_Hs() // drawing the channel's lower line by High fractals
   {ObjectDelete("Tr_B1s");
   ObjectCreate("Tr_B1s",OBJ_TREND,0,timf2b,TF2B-RazmerH*Point,timf1b,
   TF1B-RazmerH*Point); 
   ObjectSet("Tr_B1s",OBJPROP_COLOR,Lime);                      // color
   ObjectSet("Tr_B1s",OBJPROP_WIDTH,1);                     // thin line
   ObjectSet("Tr_B1s",OBJPROP_STYLE,STYLE_DOT);                 // solid
   }
// --------------------------------------------------------------------+
  void Create_Tr_Hh()       // drawing profit for the upper working line 
   {ObjectDelete("Tr_B1h");
   ObjectCreate("Tr_B1h",OBJ_TREND,0,timf2b,TF2B+
   RazmerH*Point,timf1b,TF1B+RazmerH*Point);
   ObjectSet("Tr_B1h",OBJPROP_COLOR,Aqua);                      // color
   ObjectSet("Tr_B1h",OBJPROP_WIDTH,1);                     // thin line
   ObjectSet("Tr_B1h",OBJPROP_STYLE,STYLE_DOT);                // dotted
   }
// --------------------------------------------------------------------+
  void Create_Tr_Hhh()        // drawing profit for the upper working line + 10%
   {ObjectDelete("Tr_B1hh");
   ObjectCreate("Tr_B1hh",OBJ_TREND,0,timf2b,TF2B+RazmerH*Point+
   RazmerH*Point*10/100,timf1b,TF1B+RazmerH*Point+RazmerH*Point*10/100); 
   ObjectSet("Tr_B1hh",OBJPROP_COLOR,Lime);                     // color
   ObjectSet("Tr_B1hh",OBJPROP_WIDTH,1);                    // thin line
   ObjectSet("Tr_B1hh",OBJPROP_STYLE,STYLE_DOT);               // dotted
   }
// --------------------------------------------------------------------+
  void Create_Tr_Hhs()      // drawing profit for the upper working line - 10%
   {ObjectDelete("Tr_B1hs");
   ObjectCreate("Tr_B1hs",OBJ_TREND,0,timf2b,TF2B+RazmerH*Point-
   RazmerH*Point*10/100,timf1b,TF1B+RazmerH*Point-RazmerH*Point*10/100); 
   ObjectSet("Tr_B1hs",OBJPROP_COLOR,Lime);                     // color
   ObjectSet("Tr_B1hs",OBJPROP_WIDTH,1);                    // thin line
   ObjectSet("Tr_B1hs",OBJPROP_STYLE,STYLE_DOT);               // dotted
   }
// --------------------------------------------------------------------+
  void Create_Tr_S() // drawing the channel's lower line by Low fractals 
   { 
   ObjectDelete("Tr_S1"); 
   ObjectCreate("Tr_S1",OBJ_TREND,0,timf2s,TF2S,timf1s,TF1S);
   ObjectSet("Tr_S1",OBJPROP_COLOR,Lime);                       // color 
   ObjectSet("Tr_S1",OBJPROP_WIDTH,1);                      // thin line
   ObjectSet("Tr_S1",OBJPROP_STYLE,STYLE_SOLID);                // solid 
   }
// --------------------------------------------------------------------+
  void Create_Tr_Sh() //drawing the channel's upper line by Low fractals 
   { 
   ObjectDelete("Tr_S1h"); 
   ObjectCreate("Tr_S1h",OBJ_TREND,0,timf2s,TF2S+RazmerS*Point,
   timf1s,TF1S+RazmerS*Point);
   ObjectSet("Tr_S1h",OBJPROP_COLOR,Aqua);                      // color 
   ObjectSet("Tr_S1h",OBJPROP_WIDTH,1);                     // thin line
   ObjectSet("Tr_S1h",OBJPROP_STYLE,STYLE_DOT);                // dotted
   }
// --------------------------------------------------------------------+
  void Create_Tr_Ss()       // drawing profit for the lower working line
   {  ObjectDelete("Tr_S1s");
   ObjectCreate("Tr_S1s",OBJ_TREND,0,timf2s,TF2S-RazmerS*Point,timf1s,
   TF1S-RazmerS*Point);
   ObjectSet("Tr_S1s",OBJPROP_COLOR,Aqua);                      // color
   ObjectSet("Tr_S1s",OBJPROP_WIDTH,1);                     // thin line
   ObjectSet("Tr_S1s",OBJPROP_STYLE,STYLE_DOT);                // dotted 
   }
// --------------------------------------------------------------------+
  void Create_Tr_Ssh()      // drawing profit for the lower working line (+ 10%)
   { ObjectDelete("Tr_S1sh"); 
   ObjectCreate("Tr_S1sh",OBJ_TREND,0,timf2s,TF2S-RazmerS*Point+
   RazmerS*Point*10/100,timf1s,TF1S-RazmerS*Point+RazmerS*Point*10/100);
   ObjectSet("Tr_S1sh",OBJPROP_COLOR,Lime);                     // color 
   ObjectSet("Tr_S1sh",OBJPROP_WIDTH,1);                    // thin line
   ObjectSet("Tr_S1sh",OBJPROP_STYLE,STYLE_DOT);               // dotted 
   }
// --------------------------------------------------------------------+
  void Create_Tr_Sss()          // drawing profit for the lower working line (- 10%)
   { ObjectDelete("Tr_S1ss"); 
   ObjectCreate("Tr_S1ss",OBJ_TREND,0,timf2s,TF2S-RazmerS*Point-
   RazmerS*Point*10/100,timf1s,TF1S-RazmerS*Point-RazmerS*Point*10/100);
   ObjectSet("Tr_S1ss",OBJPROP_COLOR,Lime);                     // color 
   ObjectSet("Tr_S1ss",OBJPROP_WIDTH,1);                    // thin line
   ObjectSet("Tr_S1ss",OBJPROP_STYLE,STYLE_DOT);               // dotted 
   }
//+--------------------------------------------------------------------+
  void Del_Frb()  // Delete the upper reference points (fractal signs) 
   {
   ObjectDelete("Fr1b"); ObjectDelete("Fr2b");
   }
// --------------------------------------------------------------------+
  void Del_Frs()   // Delete the lower reference points (fractal signs) 
   {
   ObjectDelete("Fr1s"); ObjectDelete("Fr2s");
   }
//+--------------------------------------------------------------------+
  void Del_TrLin()                           // Delete trend lines 
   {
   ObjectDelete("Tr_B1"); ObjectDelete("Tr_S1"); 
   }
//+--------------------------------------------------------------------+
  void CreateArrow_Frb()           // drawing the upper reference points
    {
    ObjectDelete("Fr1b");
    ObjectCreate("Fr1b",OBJ_ARROW, 0, timf1b, TF1B+0.0015);
    ObjectSet("Fr1b", OBJPROP_COLOR, Yellow);                    //color
    ObjectSet("Fr1b", OBJPROP_ARROWCODE,217);            //217-sign code
    ObjectDelete("Fr2b");
    ObjectCreate("Fr2b",OBJ_ARROW, 0, timf2b, TF2B+0.0015);
    ObjectSet("Fr2b", OBJPROP_COLOR, Yellow);                    //color
    ObjectSet("Fr2b", OBJPROP_ARROWCODE,217);            //217-sign code
    }
//+--------------------------------------------------------------------+
  void CreateArrow_Frs()           // drawing the lower reference points
    {
    ObjectDelete("Fr1s");
    ObjectCreate("Fr1s",OBJ_ARROW, 0, timf1s, TF1S-0.0005);
    ObjectSet("Fr1s", OBJPROP_COLOR, Yellow);                    //color
    ObjectSet("Fr1s", OBJPROP_ARROWCODE,218);            //218-sign code
    ObjectDelete("Fr2s");
    ObjectCreate("Fr2s",OBJ_ARROW, 0, timf2s, TF2S-0.0005);
    ObjectSet("Fr2s", OBJPROP_COLOR, Yellow);                    //color
    ObjectSet("Fr2s", OBJPROP_ARROWCODE,218);            //218-sign code
    }
// --------------------------------------------------------------------+
  void CreateLzona()    // actual breakthrough area's vertical line time
   {
   ObjectDelete("zona");          
   ObjectCreate("zona",OBJ_VLINE,0,time_bar_zona,1.3258);
   ObjectSet("zona",OBJPROP_COLOR,Red);                         // color
   ObjectSet("zona",OBJPROP_WIDTH,1);                       // thin line
   ObjectSet("zona",OBJPROP_STYLE,STYLE_DASH);                 // Dashed
   } 
// --------------------------------------------------------------------+
  void CreateLbasis()            // vertical line at the triangle's base
   {
   ObjectDelete("L1");
   ObjectCreate("L1",OBJ_VLINE,0,time_starting,1.4444);
   ObjectSet("L1",OBJPROP_COLOR,Aqua);                          // color
   ObjectSet("L1",OBJPROP_WIDTH,1);                         // thin line
   ObjectSet("L1",OBJPROP_STYLE,STYLE_DASH);              // Dash-dotted 
   } 
// --------------------------------------------------------------------+
  void CreateLApex()       // vertical line at the working line's intersection point  
   {
   ObjectDelete("Ap");
   ObjectCreate("Ap",OBJ_VLINE,0,time_Apex,1.3258);
   ObjectSet("Ap",OBJPROP_COLOR,Aqua);                          // color
   ObjectSet("Ap",OBJPROP_WIDTH,1);                         // thin line
   ObjectSet("Ap",OBJPROP_STYLE,STYLE_DASH);              // Dash-dotted 
   } 
// --------------------------------------------------------------------+
// --------------------------------------------------------------------+
 void Op_Sell_Ch()
  { 
  if(!OrderSend(Symbol(),OP_SELL,Lots,Bid,2,Ask+SL_S*Point,
      Bid-TP_S*Point," ",Magic,0,Red)) 
      { Print("  SELL order open error  # ",GetLastError()); }
      return(0);
     }
// --------------------------------------------------------------------+
 void Op_Buy_Ch()
  {
  if(!OrderSend(Symbol(),OP_BUY,Lots,Ask,2,Bid-SL_B*Point,
      Ask+TP_B*Point," ",Magic,0,Blue))
      { Print("  SELL order open error  # ",GetLastError()); }
      return(0);
     }
//+--------------------------------------------------------------------+
// void Close_B_Ch()
//  {
//  if(!OrderClose(OrderTicket(),OrderLots(),Bid,2,Aqua))  
//      {Print(" Cl.ord.# ",OrderTicket()," Error # ",GetLastError());}
//       return(0);
//     }
//+--------------------------------------------------------------------+
// void Close_S_Ch()
//  {
//  if(!OrderClose(OrderTicket(),OrderLots(),Ask,2,Aqua))  
//      {Print(" Cl.ord.# ",OrderTicket()," Error # ",GetLastError());}
//      return(0);
//     }
//+--------------------------------------------------------------------+
  void CreateTriangleH()       // drawing the Triangle by the upper line
   {
   ObjectDelete("TRH");  
   ObjectCreate("TRH",OBJ_TRIANGLE,0,timf2s,TF2S,timf2s,Starting_Price_H,
   timf2s+cut_left*T_period,P_Tria); 
   ObjectSet("TRH",OBJPROP_COLOR,Teal);                         // color 
   } 
//+--------------------------------------------------------------------+
  void CreateTriangleS()       // drawing the Triangle by the lower line
   {
   ObjectDelete("TRS");  
   ObjectCreate("TRS",OBJ_TRIANGLE,0,timf2b,TF2B,timf2b,Starting_Price_S,
   timf2b+cut_left*T_period,P_Tria); 
   ObjectSet("TRS",OBJPROP_COLOR,Teal);                         // color 
   }
// ====================================================================+
//+--------------------------------------------------------------------+
   int start()
   {
    int spread=MarketInfo(Symbol(),MODE_SPREAD);
    int StopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL);
    datetime Tm1=TimeCurrent();  // time at "0" bar
//+--------------------------------------------------------------------+
// - block of zeroing the variables  ----------------------------------+
   TF1B=0; TF2B=0; TF1S=0; TF2S=0;      // prices                      +
   Tfnb=0; Tfns=0;                      // counters                    +
   timf1b=0;timf2b=0;timf1s=0;timf2s=0; // time                        +
   Tf1b=0;Tf2b=0;Tf1s=0;Tf2s=0;         // indices                     +
   PatternTch=false;                    // pattern                     +
   RatePriceH=0;RatePriceS=0;           // price change rate           +
   Open_chenel=false;                   // enable/disable              +
   P_Tria=0;                    // price of the triangle's third angle +
// -------------------------------------block of zeroing the variables-+
//+--------------------------------------------------------------------+
   if(Volume[0]>1) return;//starting to trade at the first tick of the new bar
    { // Vol-at the first tick
//+--------------------------------------------------------------------+
//  -block of values for time frames ------------------------------------+
    switch (Period())
	 {
	 case 60:   T_period=  3600; break;
	 case 240:  T_period= 14400; break;
    default:   Alert("Your Expert Advisor is at the wrong time frame!"); 
    }
//   ----------------------------------- block of values for time frames-+
// ====================================================================+
// (upper and lower fractals searching block) -------------------------------+
   for (i=M;i<=N;i++) // reference points (fractals) searching loop
    {//loop b
   // searching for the upper fractals -----------------------------------------+
   if(High[i]>High[i+1] && High[i]>High[i+2] && 
      High[i]>High[i-1] && High[i]>High[i-2])
     {// frac_b
      Tfnb++;   // counter 
   // ----------------------------  
     if(Tfnb==1)     
	   {             // for the 1 st fractal: price, index, time.
	   TF1B=High[i]; Tf1b=i; timf1b=iTime(Symbol(),Period(),i); 
      }//-counter_1
   // ----------------------------
	  if(Tfnb==2)    
	   {//counter_2                       // price, index, time.
	    TF2B=High[i]; Tf2b=i; timf2b=iTime(Symbol(),Period(),i); break;
	   }//-counter_2
	// ----------------------------   
     }//-frac_b
    }//-b loop
// --------------------------------------------------------------------+
   for (i=M;i<=N;i++) // reference points (fractals) searching loop
    {//s loop
   // searching for lower fractals ------------------------------------------+
   if(Low[i]<Low[i+1] && Low[i]<Low[i+2] && 
      Low[i]<Low[i-1] && Low[i]<Low[i-2])
     {// frac_s
      Tfns++; 
     if(Tfns==1)     
	   {//counter_1                    // price, index, time.
	   TF1S=Low[i]; Tf1s=i; timf1s=iTime(Symbol(),Period(),i); 
	   }//-counter_1
	   if(Tfns==2)      
	    {//counter_2                    // price, index, time.
	    TF2S=Low[i]; Tf2s=i; timf2s=iTime(Symbol(),Period(),i); break;
	   }//-counter_2
     }//-frac_s
    }//- loop s 
// ----------------------------------(upper and lower fractals searching block)-+
//+æææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææ+
// -----------------------------------------------------------------------------+
// - (Block of conditions for working lines' convergence to form the Triangle) -+
   // convergence conditions necessary to form a triangle:
   // 1. The first fractals should be spaced more than 20-30 pips apart
   // 2. The first fractals of one working line should be less than the second fractals of another one
   // 3. all 4 reference points are different from "0", i.å. they have real values
   // 4. time parameters of reference points should be different from "0".
   // 5. The 1 st upper reference point is below the 2 nd upper one and the 1 st lower point is higher than the 2 nd one
   // 6. the difference between the lines' second fractals should not exceed 150 pips
// ---------------------------------------------------------------------------+
   if((TF1B-TF1S)>25*Point && 
      Tf1b<=Tf2s && Tf1s<=Tf2b && 
      TF1B>0 && TF1S>0 && TF2B>0 && TF2S>0 && 
      timf1b!=0 && timf2b!=0 && timf1s!=0 && timf2s!=0 &&
      TF1B<TF2B && TF1S>TF2S && 
      (TF2B-TF2S)/Point<150)   
    {// triangle drawing conditions
 //===========================================================================+
 // Print(" total number= ",g2," in triangles ",g1); // result: 8507; 814
//============================================================================+
// ---------------------------------------------------------------------------+
   // - (block Price change rate calculation)(upper and lower pip per one bar)
   if(TF1B!=TF2B) {RatePriceH=MathAbs((TF2B-TF1B)/(Tf2b-Tf1b));} // for the upper
   if(TF1S!=TF2S) {RatePriceS=MathAbs((TF1S-TF2S)/(Tf2s-Tf1s));} // for the lower 
   // Print(" RatePriceS= ",RatePriceS); Print(" RatePriceH= ",RatePriceH);
// -------------------------------------(block Price change rate calculation)-+
//============================================================================+
/* At this point, 4 last fractals are located according to
  the triangle forming conditions though it is not clear yet how far the Apex will be
  and where the actual breakthrough areas will be located.
  Since the calculation of Apex depends on the location of the second fractal out of the last 
  four ones during their generation (from left to right on the chart). The starting 
  point for the long working line should be defined as a vertical's intersection point
  drawn through the second fractal of the short working line by the long one.
  In this respect, the further program algorithm is branched into two directions
  of the actual breakthrough areas calculation: "long" upper and "long" lower working line. */
// --------------------------------------------------------------------------------------------------+
// æææææææææææææææææææææææ 1. upper working line is longer than the lower one  ææææææææææææææææææææææ+ 
// - (block of searching for the working line's intersection point) ---------------------------------+
// If the upper working line is longer than the lower one - find the intersection point on 50 bars
   if(Tf2b>Tf2s && TF2B>TF1B && TF2S<TF1S)
    {// The Upper working line is longer
     // the starting price for calculation of values at each bar of the upper working line 
     Starting_Price_H=TF2B-RatePriceH*(Tf2b-Tf2s); 
     // the starting price for calculation of values at each bar of the upper working line 
     Starting_Price_S=TF2S;
     //the time of drawing the vertical line at the triangle's base
     time_starting=timf2s; 
     // ------------------------------------
    for(int k=1;k<=50;k++)
    {//50b loop
     PricB[k]=Starting_Price_H-RatePriceH*k;          // minus fall rate
     PricS[k]=Starting_Price_S+RatePriceS*k;          // plus rising rate
     // if prices of the upper and lower lines' projections coincide or the price of the upper one 
    if(PricB[k]<=PricS[k])   // has become less than that of the lower one, then there is the intersection with the working line 
     {//there is the intersection
     P_Tria=PricB[k-1];                             // price of the triangle's third angle
     cut_left=k;  break;      // number of bars from the base up to the intersection point
     }//-there is the intersection
    }//-50b loop
// -------------------------------------- (block of searching for working line's intersection point)-+
// --------------------------------------------------------------------------------------------------+
// - (block of calculating time intervals for the actual breakthrough area)-------------------------------+
// Introduce two additional limitations:
// 1. The Apex should not be located more than 50 bars far from the triangle's base
// 2. The Apex should not be located closer than 15 bars to the triangle's base.
   if(cut_left<50 && cut_left>12)
    {//triangle with all limitations
     time_Apex=timf2s+cut_left*T_period;                        // Apex generation time
     //  divide the number of bars by three, take 2/3 and round them off to the integer
     // value: MathRound(cut_left/3*2) -number of bars for the actual breakthrough area
     time_bar_zona=time_starting+MathRound(cut_left/3*2)*T_period;         // area time
     //      pattern creation conditions fulfilled, actual breakthrough area calculated  
     PatternTch=true;                          // "Chuvashov's Triangle" pattern formed
     }//-triangle with all limitations
// --------------(block of calculating time intervals for the actual breakthrough area)-+
// -------------------------------------------------------------------------------------+
// - (block of drawing the triangle after the pattern has been formed) -----------------+
   if(PatternTch==true)
    {//there is a pattern
    Del_Frb(); Del_Frs();                     // delete previous upper and lower fractals
    CreateArrow_Frb(); CreateArrow_Frs();                // draw upper and lower fractals
    Create_Tr_H(); Create_Tr_S();                     // draw upper and lower trend lines
    CreateLzona(); CreateLbasis(); CreateLApex();                  // draw vertical lines
    CreateTriangleH();                             // draw the triangle by the upper line
    ObjectDelete("TRS");                 // delete the triangle drawing by the lower line
// -----------------(block of drawing the triangle after the pattern has been formed)---+  
//+===========================================================================+
// - (block of calculating the sizes of the upper and lower working lines' channels) ------------------+ 
    // calculate the channel's width (in pips) for the upper working line 
    // third point's index for building the channel by the Upper working line
    Tf3s=iLowest(NULL,0,MODE_LOW,Tf2b,0);         
    TF3S=Low[Tf3s];  // third point's price for building the channel by the Upper working line
    // channel width: - from the Upper working line, on the vertical of the third point's index, 
    // subtract the price of the 3 rd channel's reference point - receive the channel's size
    RazmerH=MathRound(((TF2B-(Tf2b-Tf3s)*RatePriceH)-TF3S)/Point); 
    // Print(" RazmerH ======= ",RazmerH);
    // -----------------------------------------------------------------------+
    // calculate the channel's width (in pips) for the Lower working line 
    // third point's index for building the channel by the Lower working line
    Tf3b=iHighest(NULL,0,MODE_HIGH,Tf2s,0);        
    TF3B=High[Tf3b]; // third point's price for the channel by the Lower working line
    // channel width: - for the Lower working line on the vertical of the third point's index, 
    // add the price of the 3 rd channel's point - receive the channel's size
    RazmerS=MathRound((TF3B-(TF2S+(Tf2s-Tf3b)*RatePriceS))/Point);
    // Print(" RazmerS ============ ",RazmerS);
// ------------------ (block of calculating the sizes of the upper and lower working lines' channels) -+
// æææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææ+
// - (block of opening positions when breaking through the working lines) ----------------------------+
    if(((High[1]>TF2B-(Tf2b-1)*RatePriceH) || 
       (High[2]>TF2B-(Tf2b-2)*RatePriceH)) && 
       // the price of the breakthrough bar should not be located from the working line for more than a half
       // of the width of the broken channel. This filter may be set when testing
       (Open[1]-TF2B-(Tf2b-1)*RatePriceH)<30*Point && 
       // breakthrough bar time in the actual breakthrough area
       iTime(Symbol(),Period(),1)<time_bar_zona &&     
       PatternTch==true && 
       OrdersTotal()<2)
     {
       Print(" =1B-label === Buy Upper line is longer - breakthrough upwards" );
      // delete the lines of channel's profit sizes by the lower working line 
      // finish drawing the channel's size and channel's profit size for the upper working line
      Create_Tr_Hh(); Create_Tr_Hhh(); Create_Tr_Hhs(); Create_Tr_Hs();
      // find a reasonable addition to SlbH on the tester for a particular condition 
      // (SlbH=43; for a close fractal or SlbH=42; for a distant fractal)
      // stop loss at the 1 st upper fractal's level (plus some supplement)
      SlbH=43; // for a close fractal
      SL_B=MathRound((Bid-TF1S)/Point+SlbH); // SlbH is defined by testing
      // or at the 2 nd Fractal's level (also, may have a supplement)
      // SlbH=42; // for a distant fractal
      // SL_B=MathRound((Bid-TF2S)/Point+SlbH);
      // if Stop Loss is close to the market:
      if(SL_B<StopLevel) SL_B=(Bid-(Bid-5*StopLevel*Point))/Point;  
      // level of the profit - 100% of the channel's width on the 1 st bar's vertical
      // TP_B=MathRound((((TF2B-(Tf2b-1)*RatePriceH)+RazmerH*Point)-Bid)/Point);
      // the value can be reduced from 10% to 100% of the channel's width to provide more safety
      TP_B=MathRound((((TF2B-(Tf2b-1)*RatePriceH)+RazmerH*Point)-Bid)/Point-
      RazmerH*10/100);
      Op_Buy_Ch();
    }
// --------------------------------------------
    if(((Low[1]<TF2S+(Tf2s-1)*RatePriceS) ||          // Min price at the 1 st bar
       (Low[2]<TF2S+(Tf2s-2)*RatePriceS)) &&          // Min price at the 2 nd bar
       // the price of the breakthrough bar should not be located from the working line for more than a half
       // of the width of the broken channel. This filter may be set when testing 
       (TF2S+(Tf2s-1)*RatePriceS)-Open[1]<30*Point && //
       iTime(Symbol(),Period(),1)<=time_bar_zona+3600 &&    // breakthrough bar's time   ###################
       PatternTch==true && 
       OrdersTotal()<2)  
      {
       Print(" =1S-label Sell Upper line is longer - breakthrough downwards");
       // finish drawing the channel's size and channel's profit size for the lower working line
       Create_Tr_Ss(); Create_Tr_Ssh(); Create_Tr_Sss();Create_Tr_Sh(); 
       // find a reasonable addition to SlsH on the tester for a particular condition 
       // (SlsH=32; for a close fractal or SlsH=20; for a distant fractal)
       // stop loss at the 1 st upper fractal's level plus some supplement 
       SlsH=32; // for a close fractal - defined by testing
       SL_S=MathRound((TF1B-Bid)/Point+SlsH); 
       // or at the 2 nd Fractal's level (also, may have a supplement)
       // SL_S=MathRound((TF2B-Bid)/Point+SlsH);
       // level of the profit - 100% of the channel's width on the 1 st bar's vertical
       // TP_S=MathRound((Bid-(TF2S+(Tf2s-1)*RatePriceS-RazmerS*Point))/Point);
       // the value can be reduced by 10% of the channel's width to provide more safety
       TP_S=MathRound((Bid-((TF2S+(Tf2s-1)*RatePriceS)-RazmerS*Point))/Point)-
       RazmerS*10/100;
       Op_Sell_Ch();
      }
// ----------------------------- (block of opening positions when breaking through the working lines)-+
     }//-there is a pattern
    }//-Upper working line is longer
// ===========================================================================+
// æææææææææææææææææææææææ 2. lower working line is longer than the upper one  ææææææææææææææææææææ--+
// - (block of searching for working line's intersection point) -------------------------------------+
// If the lower working line is longer than the upper one, find the intersection point on 50 bars
   if(Tf2s>Tf2b && TF2B>TF1B && TF2S<TF1S) 
    {//Lower working line is longer
     Starting_Price_H=TF2B;                           // upper line's starting price
     Starting_Price_S=TF2S+RatePriceS*(Tf2s-Tf2b);    // lower line's starting price
     time_starting=timf2b;                     // time to draw the starting vertical
// ------------------------------------------ 
    for(k=1;k<=50;k++)
     {//50s loop
      PricB[k]=Starting_Price_H-RatePriceH*k; 
      PricS[k]=Starting_Price_S+RatePriceS*k;
     if(PricB[k]<=PricS[k])  // has become less than that of the lower one, then there is the intersection with the working line
      {//there is the intersection
      P_Tria=PricB[k];                                 // price of the triangle's third angle
      cut_left=k; break;     // bars to the intersection point of the channel's working lines
       }//-there is the intersection
      }//-50s loop
// -------------------------------------- (block of searching for working line's intersection point)-+
// --------------------------------------------------------------------------------------------------+
// - (block of calculating time intervals for the actual breakthrough area)--------------------------+
     if(cut_left<50 && cut_left>12)
      {//if<50
      time_Apex=timf2b+cut_left*T_period;            // Apex generation time
      // actual breakthrough area time
      time_bar_zona=time_starting+MathRound(cut_left/3*2)*T_period;//area time
      PatternTch=true;                // "Chuvashov's Triangle" pattern formed
     }//-if<50
// --------------(block of calculating time intervals for the actual breakthrough area)-+
// -------------------------------------------------------------------------------------+
// - (block of drawing the triangle after the pattern has been formed) -----------------+
   if(PatternTch==true)
    {//there is a pattern
    Del_Frb(); Del_Frs();       // delete previous upper and lower fractals
    CreateArrow_Frb(); CreateArrow_Frs();  // draw upper and lower fractals
    Create_Tr_H(); Create_Tr_S();       // draw upper and lower trend lines
    CreateLzona(); CreateLbasis(); CreateLApex();    // draw vertical lines
    CreateTriangleS();               // draw the triangle by the lower line
    ObjectDelete("TRH");   // delete the triangle drawing by the upper line
// -----------------(block of drawing the triangle after the pattern has been formed)-+  
//+===========================================================================+
// - (block of calculating the sizes of the upper and lower working lines' channels) ------------------+ 
    // third point's index for building the channel by the Upper working line
    Tf3s=iLowest(NULL,0,MODE_LOW,Tf2b,0); 
    TF3S=Low[Tf3s]; // third point's price for the Lower line
    // from the Upper working line, on the vertical of the third point's index 
    // (TF2B-(Tf2b-Tf3s)*RatePriceH) subtract the channel's 3 rd point price
    RazmerH=MathRound(((TF2B-(Tf2b-Tf3s)*RatePriceH)-TF3S)/Point); 
    // Print(" RazmerH= ",RazmerH);
    // -----------------------------------------------------------------------+
    // third point's index for building the channel by the Lower working line
    Tf3b=iHighest(NULL,0,MODE_HIGH,Tf2s,0); 
    TF3B=High[Tf3b];    // third point's reference price of the channel by the Lower working line
    // from the third reference point's price, we should subtract the price 
    // of the lower working line on the vertical of the third point's channel 
    RazmerS=MathRound((TF3B-(TF2S+(Tf2s-Tf3b)*RatePriceS))/Point); 
    // Print(" RazmerS= ",RazmerS);
// ------------------- (block of calculating the sizes of the upper and lower working lines)-+
// æææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææææ+
// - (block of opening positions when breaking through the working lines) ----------------------------+
   if(((High[1]>TF2B-(Tf2b-1)*RatePriceH)  ||           
      (High[2]>TF2B-(Tf2b-2)*RatePriceH)) && 
      (Open[1]-TF2B-(Tf2s-1)*RatePriceS)<30*Point && 
      iTime(Symbol(),Period(),1)<time_bar_zona && 
      PatternTch==true && 
      OrdersTotal()<2)
     {
      // draw the channel's size and channel's profit size
      Create_Tr_Hh(); Create_Tr_Hhh(); Create_Tr_Hhs(); Create_Tr_Hs(); 
      Print(" =2B= this is the label for further analysis!!");
      // stop loss at the 1 st upper fractal's level plus some supplement 
      // by testing or at the 2 nd Fractal's level (also, may have a supplement)
      SlbS=6;
      SL_B=MathRound((Bid-TF1S)/Point+SlbS);
      // SlbS=1;
      // SL_B=MathRound((Bid-TF2S)/Point+SlbS);
      // level of the profit - 100% of the channel's width on the 1 st bar's vertical
      // TP_B=MathRound(((TF2B-(Tf2b-1)*RatePriceH+RazmerH*Point)-Bid)/Point);
      // the value can be reduced by 10% of the channel's width to provide more safety
      TP_B=MathRound((((TF2B-(Tf2b-1)*RatePriceH)+RazmerH*Point)-Bid)/Point-
      RazmerH*10/100);
      Op_Buy_Ch();
     }
// -------------------------------------------------- 
   if(((Low[1]<TF2S+(Tf2s-1)*RatePriceS) ||        // Min price at the 1 st bar
      (Low[2]<TF2S+(Tf2s-2)*RatePriceS)) &&        // Min price at the 2 nd bar
      (TF2S+(Tf2s-1)*RatePriceS)-Open[1]<30*Point && 
      iTime(Symbol(),Period(),1)<time_bar_zona &&  // breakthrough bar's time
      PatternTch==true && 
      OrdersTotal()<2)  
     {
      Create_Tr_Ss(); Create_Tr_Ssh(); Create_Tr_Sss(); Create_Tr_Sh(); 
      Print(" =2S= this is the label for further analysis!!");
      // stop loss at the 1 st upper fractal's level plus some supplement
      // by testing or at the 2 nd Fractal's level (also, may have a supplement)
      SlsS=5;
      SL_S=MathRound((TF1B-Bid)/Point+SlsS);
      // SlsS=3;
      // SL_S=MathRound((TF2B-Bid)/Point+SlsS);
      if(SL_S<StopLevel) SL_S=((Bid-10*StopLevel*Point)-Bid)/Point;
      // level of the profit - 100% of the channel's width on the 1 st bar's vertical
      // the value can be reduced by 10% of the channel's width to provide more safety
      // TP_S=MathRound((Bid-((TF2S+(Tf2s-1)*RatePriceS)-RazmerS*Point))/Point);
      TP_S=MathRound((Bid-((TF2S+(Tf2s-1)*RatePriceS)-RazmerS*Point))/Point)-
      RazmerS*10/100;
      Op_Sell_Ch();
     } 
// ---------------------------------
    }//-there is a pattern
   }//-Lower working line is longer
// ---------------------------------------------------------------------------+
    }//-triangle forming conditions
   }//Vol-at the first tick
// ===========================================================================+
// - (block defining the pattern's life time) --------------------------------+
// if the current time exceeds the actual breakthrough area boundary's time, the pattern loses its power
   if((TimeCurrent()-time_bar_zona)>=T_period)
    {
     PatternTch=false; // the pattern is outdated - introduce the ban on opening positions
    }
    // after the current time exceeds the Apex one
    if((TimeCurrent()-time_Apex)>=T_period) 
     {
      // delete pattern signs and lines from the chart 
      Del_Frs(); Del_Frb(); Del_TrLin();
      // delete the lines of channel profit size by the upper working line 
      ObjectDelete("Tr_B1h"); ObjectDelete("Tr_B1hh"); ObjectDelete("Tr_B1hs");ObjectDelete("Tr_B1s");
      // delete the lines of channel profit size by the lower working line 
      ObjectDelete("Tr_S1s"); ObjectDelete("Tr_S1sh"); ObjectDelete("Tr_S1ss");ObjectDelete("Tr_S1h");
      // delete the vertical lines of the actual breakthrough area
      ObjectDelete("L1");ObjectDelete("zona");ObjectDelete("Ap");
      ObjectDelete("TRH"); ObjectDelete("TRS");
     }
// --------------------------------------------------------------------+
// --------------------------------------------------------------------+
//              Block of tracking positions can be inserted here       +
// ---------------  similar to the block in Vilka_Ch.htm  -------------+
// --------------------------------------------------------------------+
   return(0);
  }
//+--------------------------------------------------------------------+