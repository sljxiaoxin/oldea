//+------------------------------------------------------------------+

//|                                                       xea-zigzag.mq4 |

//+------------------------------------------------------------------+
extern int      slowerMa                  = 200;
extern int      maMethod                  = 0;   //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern int ExtDepth=12;
extern int ExtDeviation=5;
extern int ExtBackstep=3;
double ZigzagBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];

int       sx = 1;
int       idx = 0;
string    strTrend="";
double    redrawtime     = 0;
int init(){
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   judgeTrend();
   
}
int start(){
   int limit;
   int shift,back;
   double val,res;
   double lasthigh,lastlow;
    string var1;
   if(redrawtime != Time[0]){
      idx +=1 ;
      judgeTrend();
      redrawtime = Time[0];
      if(idx >= 24){
         limit = idx-ExtDepth;
          ArrayResize(HighMapBuffer,idx);
          ArrayResize(LowMapBuffer,idx);
          ArrayInitialize(HighMapBuffer,0.0);
          ArrayInitialize(LowMapBuffer,0.0);
          
          for(shift=limit; shift>=4; shift--)
           {
            val=Low[iLowest(NULL,0,MODE_LOW,ExtDepth,shift)];
            if(val==lastlow) val=0.0;
            else 
              { 
               lastlow=val; 
               if((Low[shift]-val)>(ExtDeviation*Point)) val=0.0;
               else
                 {
                  for(back=1; back<=ExtBackstep; back++)
                    {
                     res=LowMapBuffer[shift+back];
                     if((res!=0)&&(res>val)) LowMapBuffer[shift+back]=0.0; 
                    }
                 }
              } 
            if (Low[shift]==val) LowMapBuffer[shift]=val; else LowMapBuffer[shift]=0.0;
            //--- high
            val=High[iHighest(NULL,0,MODE_HIGH,ExtDepth,shift)];
            if(val==lasthigh) val=0.0;
            else 
              {
               lasthigh=val;
               if((val-High[shift])>(ExtDeviation*Point)) val=0.0;
               else
                 {
                  for(back=1; back<=ExtBackstep; back++)
                    {
                     res=HighMapBuffer[shift+back];
                     if((res!=0)&&(res<val)) HighMapBuffer[shift+back]=0.0; 
                    } 
                 }
              }
            if (High[shift]==val) HighMapBuffer[shift]=val; else HighMapBuffer[shift]=0.0;
           }
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
           double g_data[]; //高点数组
           double d_data[]; //低点数组 
           int g_dataIndex[];
           int d_dataIndex[];
           int g_fori = 0;
           int d_fori = 0;
           ArrayResize(g_data,g_count);
           ArrayResize(d_data,d_count);
           ArrayResize(g_dataIndex,g_count);
           ArrayResize(d_dataIndex,d_count);
           for(i=0;i<=limit;i++){
               if(LowMapBuffer[i] >0){
                  d_data[d_fori] = LowMapBuffer[i];
                  d_dataIndex[d_fori] = i;
                  d_fori++;
               }
               if(HighMapBuffer[i]>0){
                  g_data[g_fori] = HighMapBuffer[i];
                  g_dataIndex[g_fori] = i;
                  g_fori++;
               }
           }
           
           
           
      }
   }
   Comment("zigzag index = "+idx);
   return 0;
}

//200均线以上为long，以下为short
void judgeTrend(){
   double l_slower_ma = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
   if(strTrend !="long" && Close[1] - l_slower_ma >= 80*sx*Point){
      strTrend = "long";
      idx = 1;
   }else if(strTrend !="short" && l_slower_ma - Close[1] >= 80*sx*Point){
      strTrend =  "short";
      idx = 1;
   }else{
   }
}

void setZigzagText(int limit){
          //删除文本
           ObjectsDeleteAll(0, OBJ_TEXT);
           for(int mm=limit;mm>=4;mm--){
            // Comment("value="+LowMapBuffer[i]+"\r\n");
              if(LowMapBuffer[mm] >0){
                  //var1=TimeToStr(Time[i],TIME_DATE|TIME_SECONDS);
                  ObjectCreate("text_object"+mm, OBJ_TEXT, 0, Time[mm], Low[mm]);
                  ObjectSetText("text_object"+mm, "低点", 10, "Times New Roman", Red);
                  //Print("low time = "+var1+"; index = "+i+" ; value = "+LowMapBuffer[i]);
              }
              if(HighMapBuffer[mm] >0){
                  //var1=TimeToStr(Time[i],TIME_DATE|TIME_SECONDS);
                  //Print("High time = "+var1+"; index = "+i+" ; value = "+HighMapBuffer[i]);
                  ObjectCreate("text_object"+mm, OBJ_TEXT, 0, Time[mm], High[mm]+50*Point*sx);
                  ObjectSetText("text_object"+mm, "高点", 10, "Times New Roman", White);
              }
           }
}