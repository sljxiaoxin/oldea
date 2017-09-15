//--------------------------------------------------------------------
// Martingale.mq4
// 
//--------------------------------------------------------------- 1 --
#property copyright "Copyright 2016.08.09"
#property link      "http://goldandforex168.com/robot/su-dung"
#property version   "1.0"
//--------------------------------------------------------------- 2 --
#include <stdlib.mqh>
#include <stderror.mqh>
#include <WinUser32.mqh>
//--------------------------------------------------------------- 3 --
#include <ENUM.mqh>
#include <Variables.mqh>
#include <Criterion.mqh>           // Trading criteria
#include <CandleRecognize.mqh>
#include <Terminal.mqh>            // Order accounting
#include <Trade.mqh>               // Trade function
#include <Open_Ord.mqh>            // Open one order of the preset type
#include <Close_Ord.mqh>
#include <TradeOrder.mqh>
#include <Martingale.mqh>
#include <ActionOnce.mqh>
#include <Errors.mqh>      // Error processing function
#include <Donate.mqh>
#include <Trace.mqh>       // Trace running status
#include <ProfitProtector.mqh>
//--------------------------------------------------------------- 4 --

int init() //special function init
{
     SetVariables();
     Terminal();                         // Order accounting function     
     TraceRunning();                     //
     return(0);                          // Exit init() 
}
//--------------------------------------------------------------- 5 --
int start() // 
{
     Terminal();                                   // Order accounting function 
     Trade(Criterion());                          // Trade function use criterion RSI Roller system    
     CheckMartingale();                            // Check for martingale conditions
     ProfitProtector();
     LossProtector();     
     TraceRunning();
     return(0);                                    // Exit start()
}
//--------------------------------------------------------------- 6 --
int deinit() // Special function deinit()
{
     DeleteDonateLabels();              // To delete donate labels
     return(0);                         // Exit deinit()
}

//+------------------------------------------------------------------+
