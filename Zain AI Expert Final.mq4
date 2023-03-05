//+------------------------------------------------------------------+
//|                                         Zain AI Expert Final.mq4 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Eng. Ali Maher"
#property link      "https://www.facebook.com/eng.aly.maher"
#property version   "1.00"
#include <stdlib.mqh>
//+------------------------------------------------------------------+
input string Main_Controls="--------------------------------------------------------------------------------------------------------------------------";
extern bool Expert_Pause=False;
input ENUM_TIMEFRAMES Market_Frame= PERIOD_CURRENT;
//+------------------------------------------------------------------+
enum Opening_method
  {
   Lead_candle_open,
   Lag_candle_open,
   Price_open
  };

extern Opening_method Opening_method_select = Lead_candle_open;

//+------------------------------------------------------------------+

enum Recover_method
  {
   Normal_recover,
   Fast_recover,
   Pro_recover
  };

extern Recover_method Recover_method_Select = Normal_recover;
//+------------------------------------------------------------------+
//2- Global variables declaration & initialization
input string Main_Parameters="--------------------------------------------------------------------------------------------------------------------------";
extern int Slippage_points=3;
extern double Starting_LotSize = 0.01;
extern int Step_Points = 0;
extern int MagicNumber = 123;
extern int Profit_Points=10;
extern int Start_Profit_points=10;
extern int Profit_points_Step=0;
extern int Profit_points_limit=100;
extern string LOT_CONTROL="------------------------------------------------------------------------------------------------------------------------------";
extern int Start_Averaging_points=90;
extern int Averaging_points_Step=0;
extern int Averaging_points_limit=100;
extern double Max_averaging_lot=5;
//+------------------------------------------------------------------+
input string Trailing_Profit_Setting="--------------------------------------------------------------------------------------------------------------------------";
extern int Buy_trailprofit_start_inpoints=50;
extern int Buy_trailing_profit_points = 25;
extern int Sell_trailprofit_start_inpoints=50;
extern int Sell_trailing_profit_points = 25;
//+------------------------------------------------------------------+
int pos_0,Buy_Profit_Points,Sell_Profit_Points,Buy_count,Sell_count,BuyTicket,SellTicket,Slippage_value,Pair_open_trades,Pair_history_trades;
double Total_trailing_points,Tpcal_Sell,Stopcal_Buy,Tpcal_Buy,Stopcal_Sell,Stop_current,TProfit_current,Averaging_points,Bopen_Price,Sopen_Price,Buy_Target_Profit,Buy_Averaging_points,Sell_Target_Profit,Sell_Averaging_points,Point_value,Buy_LotSize,Sell_LotSize,Minimum_stoploss_value,Gross_profit_loss,Buy_gross_profit_loss,Sell_gross_profit_loss,Max_gross_profit_loss,Max_Buy_gross_profit_loss,Max_Sell_gross_profit_loss,Buy_trades_profit,Sell_trades_profit,Current_profit_loss,Buy_trades_lot,Sell_trades_lot,Net_lot,BuyStopLoss,SellStopLoss,BuyTakeProfit,SellTakeProfit,Sell_OP,Buy_OP,First_Sell_OP,First_Buy_OP,Sell_MLS,Buy_MLS;
bool  Stop_Placing,Select,Closed,Modify,Sell_TP,Buy_TP;
string Trend,ErrAlert;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

   int result = connectServer();
   if(result != 0)
     {
      Print("Error connecting to server: ", result);
      return INIT_FAILED;
     }
   Point_value = Point_value_calc();//calling the Point_value_calc function and return with the value
   Slippage_value = Slippage_points_calc();//calling the Slippage_points_calc function and return with the value
   Minimum_stoploss_value = Minimum_stoploss_points_calc();
   Averaging_points=Start_Averaging_points;

   Buy_Averaging_points=Start_Averaging_points;
   Sell_Averaging_points=Start_Averaging_points;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   double minTakeProfit = MarketInfo(Symbol(), MODE_STOPLEVEL);

   Trades_Counter();
   Gross_Profit_Loss();
   Current_Profit_Loss();
   Net_Lot();
   Buy_MTLS();
   Sell_MTLS();
   Buy_Lot_Averaging();
   Sell_Lot_Averaging();
   Total_Trailing_profit();

   if(Buy_count==0 && Sell_count==0)
     {
      Buy_TP=False;
      Sell_TP=False;
      Trend="Neutral";
     }
//+------------------------------------------------------------------+
   if(Buy_count==0 && Sell_count>=0 && Sell_TP==false)
     {
      //Buy_TP=false;

      if(Buy_LotSize<Sell_MLS)
         Buy_LotSize=Sell_MLS;
      else
         Buy_LotSize=Starting_LotSize;

      Bopen_Price=Close[1];
      Buy_trade();
      Buy_LTOP();

     }
//+------------------------------------------------------------------+
   if(Sell_count==0 && Buy_count>=0 && Buy_TP==false)
     {
      //Sell_TP=False;
      if(Sell_LotSize<Buy_MLS)
         Sell_LotSize=Buy_MLS;
      else
         Sell_LotSize=Starting_LotSize;

      Sopen_Price=Close[1];
      Sell_trade();
      Sell_LTOP();
     }

//+------------------------------------------------------------------+
   if(Opening_method_select == 0)
     {
      if(Recover_method_Select == 0)
        {
         if(Buy_count >0  && Sell_count == 1 && Bopen_Price!=Close[1]  && Close[1]<(Buy_OP - (Step_Points*Point_value))&& Buy_LotSize>=0.01 && Sell_TP==False)
           {
            Trend="Sell";
            Bopen_Price=Close[1];
            Buy_trade();
            Buy_LTOP();

           }
         //+------------------------------------------------------------------+
         if(Sell_count >0  && Buy_count==1 && Sopen_Price!=Close[1] && Close[1]>(Sell_OP+ (Step_Points * Point_value))&& Sell_LotSize>=0.01 && Buy_TP==False)
           {
            Trend="Buy";
            Sopen_Price=Close[1];
            Sell_trade();
            Sell_LTOP();

           }
        }
      //+------------------------------------------------------------------+
      else
         if(Recover_method_Select==1)
           {
            if(Buy_count >0  && Bopen_Price!=Close[1] && Close[1]<(Buy_OP - (Step_Points*Point_value)) && Buy_LotSize>=0.01)
              {
               Bopen_Price=Close[1];
               Buy_trade();
               Buy_LTOP();

               if(Buy_Averaging_points > Averaging_points_limit)
                  Buy_Averaging_points=Buy_Averaging_points-Averaging_points_Step;

               if(Buy_Profit_Points < Profit_points_limit)
                  Buy_Profit_Points=Buy_Profit_Points+Profit_points_Step;
              }
            //+------------------------------------------------------------------+
            if(Sell_count >0 && Sopen_Price!=Close[1] && Close[1]>(Sell_OP+ (Step_Points * Point_value)) && Sell_LotSize>=0.01)
              {
               Sopen_Price=Close[1];
               Sell_trade();
               Sell_LTOP();

               if(Sell_Averaging_points > Averaging_points_limit)
                  Sell_Averaging_points=Sell_Averaging_points-Averaging_points_Step;

               if(Sell_Profit_Points < Profit_points_limit)
                  Sell_Profit_Points=Sell_Profit_Points+Profit_points_Step;
              }
           }
         //+------------------------------------------------------------------+
         else
            if(Recover_method_Select==2)
              {
               if(Buy_count >0  && Bopen_Price!=Close[1] && Close[1]<(Buy_OP - (Step_Points*Point_value)) && Buy_LotSize>=0.01)
                 {
                  Bopen_Price=Close[1];
                  Buy_trade();
                  Buy_LTOP();

                  if(Buy_Averaging_points < Averaging_points_limit)
                     Buy_Averaging_points=Buy_Averaging_points+Averaging_points_Step;

                  if(Buy_Profit_Points > Profit_points_limit)
                     Buy_Profit_Points=Buy_Profit_Points-Profit_points_Step;
                 }
               //+------------------------------------------------------------------+
               if(Sell_count >0 && Sopen_Price!=Close[1] && Close[1]>(Sell_OP+ (Step_Points * Point_value)) && Sell_LotSize>=0.01)
                 {
                  Sopen_Price=Close[1];
                  Sell_trade();
                  Sell_LTOP();

                  if(Sell_Averaging_points < Averaging_points_limit)
                     Sell_Averaging_points=Sell_Averaging_points+Averaging_points_Step;

                  if(Sell_Profit_Points > Profit_points_limit)
                     Sell_Profit_Points=Sell_Profit_Points-Profit_points_Step;
                 }
              }
     }
//+------------------------------------------------------------------+
   else
      if(Opening_method_select==1)
        {
         if(Recover_method_Select==0)
           {
            if(Buy_count >0  && Bopen_Price!=Close[1]  && Close[1]> Open[1] && Close[1]<(Buy_OP - (Step_Points*Point_value)) && Buy_LotSize>=0.01)
              {
               Bopen_Price=Close[1];
               Buy_trade();
               Buy_LTOP();

              }
            //+------------------------------------------------------------------+
            if(Sell_count >0  && Sopen_Price!=Close[1]  && Close[1]< Open[1] && Close[1]>(Sell_OP+ (Step_Points * Point_value)) && Sell_LotSize>=0.01)
              {
               Sopen_Price=Close[1];
               Sell_trade();
               Sell_LTOP();

              }
           }
         //+------------------------------------------------------------------+
         else
            if(Recover_method_Select==1)
              {
               if(Buy_count >0  && Bopen_Price!=Close[1] && Close[1]> Open[1] && Close[1]<(Buy_OP - (Step_Points*Point_value)) && Buy_LotSize>=0.01)
                 {
                  Bopen_Price=Close[1];
                  Buy_trade();
                  Buy_LTOP();

                  if(Buy_Averaging_points > Averaging_points_limit)
                     Buy_Averaging_points=Buy_Averaging_points-Averaging_points_Step;

                  if(Buy_Profit_Points < Profit_points_limit)
                     Buy_Profit_Points=Buy_Profit_Points+Profit_points_Step;
                 }
               //+------------------------------------------------------------------+
               if(Sell_count >0 && Sopen_Price!=Close[1] && Close[1]< Open[1] && Close[1]>(Sell_OP+ (Step_Points * Point_value)) && Sell_LotSize>=0.01)
                 {
                  Sopen_Price=Close[1];
                  Sell_trade();
                  Sell_LTOP();

                  if(Sell_Averaging_points > Averaging_points_limit)
                     Sell_Averaging_points=Sell_Averaging_points-Averaging_points_Step;

                  if(Sell_Profit_Points < Profit_points_limit)
                     Sell_Profit_Points=Sell_Profit_Points+Profit_points_Step;
                 }

              }
            //+------------------------------------------------------------------+
            else
               if(Recover_method_Select==2)
                 {
                  //Net_Lot();
                  if(Buy_count >0  && Bopen_Price!=Close[1] && Close[1]> Open[1] && Close[1]<(Buy_OP - (Step_Points*Point_value)) && Buy_LotSize>=0.01)
                    {
                     Bopen_Price=Close[1];
                     Buy_trade();
                     Buy_LTOP();

                     if(Buy_Averaging_points < Averaging_points_limit)
                        Buy_Averaging_points=Buy_Averaging_points+Averaging_points_Step;

                     if(Buy_Profit_Points > Profit_points_limit)
                        Buy_Profit_Points=Buy_Profit_Points-Profit_points_Step;
                    }
                  //+------------------------------------------------------------------+
                  if(Sell_count >0 && Sopen_Price!=Close[1] && Close[1]< Open[1] && Close[1]>(Sell_OP+ (Step_Points * Point_value)) && Sell_LotSize>=0.01)
                    {
                     Sopen_Price=Close[1];
                     Sell_trade();
                     Sell_LTOP();

                     if(Sell_Averaging_points < Averaging_points_limit)
                        Sell_Averaging_points=Sell_Averaging_points+Averaging_points_Step;

                     if(Sell_Profit_Points > Profit_points_limit)
                        Sell_Profit_Points=Sell_Profit_Points-Profit_points_Step;
                    }
                 }

        }
      //+------------------------------------------------------------------+
      else
         if(Opening_method_select==2)
           {
            if(Recover_method_Select==0)
              {
               if(Buy_count >0  && Sell_count==1 && Ask<=(Buy_OP - (Step_Points*Point_value)) && Buy_LotSize>=0.01 && Buy_TP==False)
                 {
                  Trend="Sell";
                  Bopen_Price=Close[1];
                  Buy_trade();
                  Buy_LTOP();

                 }
               //+------------------------------------------------------------------+
               if(Sell_count >0 && Buy_count==1 && Bid>=(Sell_OP+ (Step_Points * Point_value)) && Sell_LotSize>=0.01 && Sell_TP==False)
                 {
                  Trend="Buy";
                  Sopen_Price=Close[1];
                  Sell_trade();
                  Sell_LTOP();

                 }
              }
            //+------------------------------------------------------------------+
            else
               if(Recover_method_Select==1)
                 {
                  //Net_Lot();
                  if(Buy_count >0  && Ask<=(Buy_OP - (Step_Points*Point_value)) && Buy_LotSize>=0.01)
                    {
                     Bopen_Price=Close[1];
                     Buy_trade();
                     Buy_LTOP();

                     if(Buy_Averaging_points > Averaging_points_limit)
                        Buy_Averaging_points=Buy_Averaging_points-Averaging_points_Step;

                     if(Buy_Profit_Points < Profit_points_limit)
                        Buy_Profit_Points=Buy_Profit_Points+Profit_points_Step;
                    }
                  //+------------------------------------------------------------------+
                  if(Sell_count >0 && Bid>=(Sell_OP+ (Step_Points * Point_value)) && Sell_LotSize>=0.01)
                    {
                     Sopen_Price=Close[1];
                     Sell_trade();
                     Sell_LTOP();

                     if(Sell_Averaging_points > Averaging_points_limit)
                        Sell_Averaging_points=Sell_Averaging_points-Averaging_points_Step;

                     if(Sell_Profit_Points < Profit_points_limit)
                        Sell_Profit_Points=Sell_Profit_Points+Profit_points_Step;
                    }

                 }
               //+------------------------------------------------------------------+
               else
                  if(Recover_method_Select==2)
                    {
                     //Net_Lot();
                     if(Buy_count >0  && Ask<=(Buy_OP - (Step_Points*Point_value)) && Buy_LotSize>=0.01)
                       {
                        Bopen_Price=Close[1];
                        Buy_trade();
                        Buy_LTOP();

                        if(Buy_Averaging_points < Averaging_points_limit)
                           Buy_Averaging_points=Buy_Averaging_points+Averaging_points_Step;

                        if(Buy_Profit_Points > Profit_points_limit)
                           Buy_Profit_Points=Buy_Profit_Points-Profit_points_Step;
                       }
                     //+------------------------------------------------------------------+
                     if(Sell_count >0 && Bid>=(Sell_OP+ (Step_Points * Point_value)) && Sell_LotSize>=0.01)
                       {
                        Sopen_Price=Close[1];
                        Sell_trade();
                        Sell_LTOP();

                        if(Sell_Averaging_points < Averaging_points_limit)
                           Sell_Averaging_points=Sell_Averaging_points+Averaging_points_Step;

                        if(Sell_Profit_Points > Profit_points_limit)
                           Sell_Profit_Points=Sell_Profit_Points-Profit_points_Step;
                       }
                    }

           }
   Comment(
      "                             Trend =",Trend,"  SellTP=",Sell_TP,"  BuyTP=",Buy_TP,"  Sellprofit=",Sell_LotSize,"  Buyprofit=",Buy_LotSize,"  profit=",Current_profit_loss,"  GPL=",Gross_profit_loss,"  MGPL=",Max_gross_profit_loss);

  }
//+------------------------------------------------------------------+
//New function to get the current symbol point value
double Point_value_calc()
  {
   if(Digits == 2 || Digits == 3)
      Point_value = 0.01;
   else
      if(Digits == 4 || Digits == 5)
         Point_value = 0.0001;
   return(Point_value);
  }
//+------------------------------------------------------------------+
//New function to determine the current symbol max Slippage points
double Slippage_points_calc()
  {
   if(Digits == 2 || Digits == 4)
      Slippage_value = Slippage_points;
   else
      if(Digits == 3 || Digits == 5)
         Slippage_value = Slippage_points*10;
   return(Slippage_value);
  }

//+------------------------------------------------------------------+
//New function to determine the current Minimum stoploss points
double Minimum_stoploss_points_calc()
  {
   if(Digits == 2 || Digits == 4)
      Minimum_stoploss_value = MarketInfo(Symbol(),MODE_STOPLEVEL);
   else
      if(Digits == 3 || Digits == 5)
         Minimum_stoploss_value = MarketInfo(Symbol(),MODE_STOPLEVEL)/10;
   return(Minimum_stoploss_value);
  }

//+------------------------------------------------------------------+
void Total_Trailing_profit()
  {
   if(Trend=="Sell")
     {
      if((Gross_profit_loss + Current_profit_loss) >= (Net_lot * 10 * Profit_Points + Max_gross_profit_loss)&& Net_lot>0)
        {
         Total_trailing_points=(Current_profit_loss)/(4*Net_lot*10);
         Stopcal_Buy=NormalizeDouble(Bid-(Total_trailing_points*Point_value),Digits);
         Tpcal_Sell=NormalizeDouble(Ask-(Total_trailing_points*Point_value),Digits);

         if(Bid-Stopcal_Buy> (Minimum_stoploss_value*Point_value)&& Ask-Tpcal_Sell > (Minimum_stoploss_value*Point_value))
           {
            Buy_TP=True;Sell_TP=True;

            for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
              {
               Select= OrderSelect(pos_0,SELECT_BY_POS,MODE_TRADES);

               if(OrderSymbol()== Symbol())
                 {

                  if(OrderType()==OP_BUY && OrderMagicNumber() == MagicNumber)
                    {
                     Stop_current=OrderStopLoss();
                     //////////////////////////////////////////////////////////
                     if(Stop_current==0 && Stopcal_Buy)
                       {
                        Modify= OrderModify(OrderTicket(),OrderOpenPrice(),Stopcal_Buy,OrderTakeProfit(),0,CLR_NONE);
                        if(Modify == 0)
                           Error_Handler();
                       }
                     else
                        if(Stopcal_Buy>Stop_current)
                          {
                           Modify= OrderModify(OrderTicket(),OrderOpenPrice(),Stopcal_Buy,OrderTakeProfit(),0,CLR_NONE);
                           if(Modify == 0)
                              Error_Handler();
                          }
                    }
                  //+------------------------------------------------------------------+
                  else
                     if(OrderType()==OP_SELL && OrderMagicNumber() == MagicNumber)
                       {

                        TProfit_current=OrderTakeProfit();
                        //////////////////////////////////////////////////////////
                        if(TProfit_current==0)
                          {
                           Modify= OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),Tpcal_Sell,0,CLR_NONE);
                           if(Modify == 0)
                              Error_Handler();
                          }
                        else
                           if(Tpcal_Sell > TProfit_current)
                             {
                              Modify= OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),Tpcal_Sell,0,CLR_NONE);
                              if(Modify == 0)
                                 Error_Handler();
                             }

                       }

                  //+------------------------------------------------------------------+
                 }
              }
           }
        }
      //+------------------------------------------------------------------+
      else
         if(Ask <= Sell_OP - (Sell_trailprofit_start_inpoints*Point_value) && Sell_trades_lot>0 && Buy_TP==False)
           {

            for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
              {
               Select=OrderSelect(pos_0,SELECT_BY_POS,MODE_TRADES);

               if(OrderSymbol()== Symbol())
                 {

                  if(OrderType()==OP_SELL && OrderMagicNumber() == MagicNumber)
                    {

                     Stop_current=OrderStopLoss();
                     Stopcal_Sell=NormalizeDouble(Ask+(Sell_trailing_profit_points*Point_value),Digits);
                     //////////////////////////////////////////////////////////
                     if(Stop_current==0)
                       {
                        Modify= OrderModify(OrderTicket(),OrderOpenPrice(),Stopcal_Sell,OrderTakeProfit(),0,CLR_NONE);
                        if(Modify == 0)
                           Error_Handler();
                       }
                     else
                        if(Stopcal_Sell<Stop_current)
                          {
                           Modify= OrderModify(OrderTicket(),OrderOpenPrice(),Stopcal_Sell,OrderTakeProfit(),0,CLR_NONE);
                           if(Modify == 0)
                              Error_Handler();
                          }
                    }


                 }
              }
           }
     }

//+------------------------------------------------------------------+
   else
      if(Trend=="Buy")
        {

         if((Gross_profit_loss + Current_profit_loss) >= (Net_lot * 10 * Profit_Points + Max_gross_profit_loss) && Net_lot>0)
           {
            Total_trailing_points=(Current_profit_loss)/(4*Net_lot*10);
            Stopcal_Sell=NormalizeDouble(Ask+(Total_trailing_points*Point_value),Digits);
            Tpcal_Buy=NormalizeDouble(Bid+(Total_trailing_points*Point_value),Digits);

            if(Stopcal_Sell-Ask > (Minimum_stoploss_value*Point_value)&& Tpcal_Buy-Bid > (Minimum_stoploss_value*Point_value))
              {
               Sell_TP=True;Buy_TP=True;

               for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
                 {
                  Select=OrderSelect(pos_0,SELECT_BY_POS,MODE_TRADES);

                  if(OrderSymbol()== Symbol())
                    {

                     if(OrderType()==OP_SELL && OrderMagicNumber() == MagicNumber)
                       {

                        Stop_current=OrderStopLoss();
                        //////////////////////////////////////////////////////////
                        if(Stop_current==0)
                          {
                           Modify= OrderModify(OrderTicket(),OrderOpenPrice(),Stopcal_Sell,OrderTakeProfit(),0,CLR_NONE);
                           if(Modify == 0)
                              Error_Handler();
                          }
                        else
                           if(Stopcal_Sell<Stop_current)
                             {
                              Modify= OrderModify(OrderTicket(),OrderOpenPrice(),Stopcal_Sell,OrderTakeProfit(),0,CLR_NONE);
                              if(Modify == 0)
                                 Error_Handler();
                             }
                       }
                     //+------------------------------------------------------------------+
                     else
                        if(OrderType()== OP_BUY && OrderMagicNumber() == MagicNumber)
                          {
                           TProfit_current=OrderTakeProfit();
                           //////////////////////////////////////////////////////////
                           if(TProfit_current==0)
                             {
                              Modify= OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),Tpcal_Buy,0,CLR_NONE);
                              if(Modify == 0)
                                 Error_Handler();
                             }
                           else
                              if(Tpcal_Buy < TProfit_current)
                                {
                                 Modify= OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),Tpcal_Buy,0,CLR_NONE);
                                 if(Modify == 0)
                                    Error_Handler();
                                }

                          }
                     //+------------------------------------------------------------------+

                    }
                 }
              }
           }
         //+------------------------------------------------------------------+
         else
            if(Bid >= Buy_OP + (Buy_trailprofit_start_inpoints*Point_value)  && Buy_trades_lot>0 && Sell_TP==false)
              {

               for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)

                 {
                  Select= OrderSelect(pos_0,SELECT_BY_POS,MODE_TRADES);

                  if(OrderSymbol()== Symbol())
                    {

                     if(OrderType()==OP_BUY && OrderMagicNumber() == MagicNumber)
                       {
                        Stop_current=OrderStopLoss();
                        Stopcal_Buy=NormalizeDouble(Bid-(Buy_trailing_profit_points*Point_value),Digits);

                        if(Stop_current==0)
                          {
                           Modify= OrderModify(OrderTicket(),OrderOpenPrice(),Stopcal_Buy,OrderTakeProfit(),0,CLR_NONE);
                           if(Modify == 0)
                              Error_Handler();
                          }
                        else
                           if(Stopcal_Buy>Stop_current)
                             {
                              Modify= OrderModify(OrderTicket(),OrderOpenPrice(),Stopcal_Buy,OrderTakeProfit(),0,CLR_NONE);
                              if(Modify == 0)
                                 Error_Handler();
                             }
                       }
                     //////////////////////////////////////////////////////////


                    }
                 }
              }
        }

  }
//+------------------------------------------------------------------+
void Close_Buy_trades()
  {
   while(Buy_count>0)
     {
      for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
        {
         Select=OrderSelect(pos_0,SELECT_BY_POS,MODE_TRADES);
         if(OrderSymbol()== Symbol())
           {
            if(OrderType()==OP_BUY && OrderMagicNumber() == MagicNumber)
              {
               Closed=OrderClose(OrderTicket(),OrderLots(),Bid,3,CLR_NONE);
               if(Closed == 0)
                  Error_Handler();
              }
           }
        }
      Trades_Counter();
     }
  }
//+------------------------------------------------------------------+
void Close_Sell_trades()
  {
   while(Sell_count>0)
     {
      for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
        {
         Select=OrderSelect(pos_0,SELECT_BY_POS,MODE_TRADES);
         if(OrderSymbol()== Symbol())
           {
            if(OrderType()==OP_SELL && OrderMagicNumber() == MagicNumber)
              {
               Closed= OrderClose(OrderTicket(),OrderLots(),Ask,3,CLR_NONE);
               if(Closed == 0)
                  Error_Handler();
              }
           }
        }
      Trades_Counter();

     }
  }
//+------------------------------------------------------------------+
void Close_all_trades()
  {
   while(Buy_count>0 || Sell_count>0)
     {
      for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
        {
         Select=OrderSelect(pos_0,SELECT_BY_POS,MODE_TRADES);
         if(OrderSymbol()== Symbol())
           {
            if(OrderType()==OP_BUY && OrderMagicNumber() == MagicNumber)
              {
               Closed=OrderClose(OrderTicket(),OrderLots(),Bid,3,CLR_NONE);
               if(Closed == 0)
                  Error_Handler();
              }
            else
               if(OrderType()==OP_SELL && OrderMagicNumber() == MagicNumber)
                 {
                  Closed= OrderClose(OrderTicket(),OrderLots(),Ask,3,CLR_NONE);
                  if(Closed == 0)
                     Error_Handler();
                 }
           }
        }
      Trades_Counter();
     }
  }
//+------------------------------------------------------------------+
void Trades_Counter()
  {
   Buy_count = Count(OP_BUY, Symbol(), MagicNumber);
   Sell_count = Count(OP_SELL, Symbol(), MagicNumber);
  }
//+------------------------------------------------------------------+
//New function for the trades counter
int Count(int Order_type, string Pair_symbol, int Magic_number)
  {

   int Total = 0;
   for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
     {
      if(OrderSelect(pos_0, SELECT_BY_POS, MODE_TRADES))
         if(OrderType() == Order_type && OrderSymbol() == Pair_symbol && OrderMagicNumber() == Magic_number)
            Total++;
     }
   return (Total);
  }
//+------------------------------------------------------------------+
void Buy_trade()
  {


   if(!IsConnected())
     {
      Print("Not connected to server");
      return;
     }
   if(!IsTradeAllowed())
     {
      Print("Trading not allowed");
      return;
     }
   if(AccountFreeMarginCheck(Symbol(),OP_BUY,Buy_LotSize)<=0)
     {
      Print("Not enough free margin");
      return;
     }
   while(IsTradeContextBusy())
      Sleep(10);
   RefreshRates();
   BuyTicket = OrderSend(Symbol(),OP_BUY,Buy_LotSize,Ask,Slippage_value,BuyStopLoss,BuyTakeProfit,"Zain AI Expert Buy",MagicNumber,0,Green);
   if(BuyTicket < 0)
      Error_Handler();
  }
//+------------------------------------------------------------------+
void Sell_trade()
  {
   if(!IsConnected())
     {
      Print("Not connected to server");
      return;
     }
   if(!IsTradeAllowed())
     {
      Print("Trading not allowed");
      return;
     }
   if(AccountFreeMarginCheck(Symbol(),OP_SELL,Sell_LotSize)<=0)
     {
      Print("Not enough free margin");
      return;
     }

   while(IsTradeContextBusy())
      Sleep(10);
   RefreshRates();
   SellTicket = OrderSend(Symbol(),OP_SELL,Sell_LotSize,Bid,Slippage_value,SellStopLoss,SellTakeProfit,"Zain AI Expert Sell",MagicNumber,0,Red);
   if(SellTicket < 0)
      Error_Handler();
  }
//+------------------------------------------------------------------+
void Buy_LTOP()
  {
   for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
     {
      Select=OrderSelect(pos_0, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderType() == OP_BUY && OrderMagicNumber() == MagicNumber)
         Buy_OP = OrderOpenPrice();
     }
  }
//+------------------------------------------------------------------+
void Sell_LTOP()
  {
   for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
     {
      Select=OrderSelect(pos_0, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderType() == OP_SELL && OrderMagicNumber() == MagicNumber)
         Sell_OP = OrderOpenPrice();
     }
  }
//+------------------------------------------------------------------+
void Buy_FTOP()
  {
   for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
     {
      Select=OrderSelect(pos_0, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderType() == OP_BUY && OrderMagicNumber() == MagicNumber)
         First_Buy_OP = OrderOpenPrice();
      break;
     }
  }
//+------------------------------------------------------------------+
void Sell_FTOP()
  {
   for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
     {
      Select=OrderSelect(pos_0, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderType() == OP_SELL && OrderMagicNumber() == MagicNumber)
         First_Sell_OP = OrderOpenPrice();
      break;
     }
  }

//+------------------------------------------------------------------+
void Buy_MTLS()
  {

   Buy_MLS =0;
   for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
     {
      Select=OrderSelect(pos_0, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderType() == OP_BUY && OrderMagicNumber() == MagicNumber)
         if(Buy_MLS < OrderLots())
            Buy_MLS=OrderLots();
     }
  }
//+------------------------------------------------------------------+
void Sell_MTLS()
  {
   Sell_MLS=0;
   for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
     {
      Select=OrderSelect(pos_0, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() == Symbol() && OrderType() == OP_SELL && OrderMagicNumber() == MagicNumber)
         if(Sell_MLS < OrderLots())
            Sell_MLS=OrderLots();
     }
  }
//+------------------------------------------------------------------+
void Gross_Profit_Loss()
  {
   Pair_history_trades=0;
   Buy_gross_profit_loss=0;
   Sell_gross_profit_loss=0;
   Gross_profit_loss=0;

   for(pos_0 = 0; pos_0 < OrdersHistoryTotal(); pos_0++)
     {
      Select= OrderSelect(pos_0,SELECT_BY_POS,MODE_HISTORY);

      if(OrderSymbol() == Symbol())
        {
         if(OrderType()==OP_BUY && OrderMagicNumber() == MagicNumber)
           {
            Buy_gross_profit_loss+=(OrderProfit()+OrderCommission()+OrderSwap());
            Pair_history_trades++;
           }
         else
            if(OrderType()==OP_SELL && OrderMagicNumber() == MagicNumber)
              {
               Sell_gross_profit_loss+=(OrderProfit()+OrderCommission()+OrderSwap());
               Pair_history_trades++;
              }
        }
     }

   Gross_profit_loss = Buy_gross_profit_loss + Sell_gross_profit_loss;

   if(Buy_gross_profit_loss > Max_Buy_gross_profit_loss)
      Max_Buy_gross_profit_loss=Buy_gross_profit_loss;

   if(Sell_gross_profit_loss > Max_Sell_gross_profit_loss)
      Max_Sell_gross_profit_loss=Sell_gross_profit_loss;

   if(Gross_profit_loss > Max_gross_profit_loss && Buy_count==0 && Sell_count==0)
      Max_gross_profit_loss=Gross_profit_loss;
  }
//+------------------------------------------------------------------+
void Current_Profit_Loss()
  {
   Pair_open_trades=0;
   Buy_trades_profit=0;
   Sell_trades_profit=0;
   Current_profit_loss=0;

   for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
     {
      Select= OrderSelect(pos_0,SELECT_BY_POS,MODE_TRADES);

      if(OrderSymbol()== Symbol())
        {
         if(OrderType()==OP_BUY && OrderMagicNumber() == MagicNumber)
           {
            Buy_trades_profit+=(OrderProfit()+OrderSwap()+OrderCommission());
            Pair_open_trades++;
           }
         else
            if(OrderType()==OP_SELL && OrderMagicNumber() == MagicNumber)
              {
               Sell_trades_profit+=(OrderProfit()+OrderSwap()+OrderCommission());
               Pair_open_trades++;
              }
        }

      Current_profit_loss=Buy_trades_profit+Sell_trades_profit;
     }
  }
//+------------------------------------------------------------------+
void Net_Lot()
  {
   Buy_trades_lot=0;
   Sell_trades_lot=0;
   Net_lot=0;

   for(pos_0 = 0; pos_0 < OrdersTotal(); pos_0++)
     {
      Select= OrderSelect(pos_0,SELECT_BY_POS,MODE_TRADES);

      if(OrderSymbol()== Symbol())
        {

         if(OrderType()==OP_BUY && OrderMagicNumber() == MagicNumber)
           {
            Buy_trades_lot+=OrderLots();
           }

         else
            if(OrderType()==OP_SELL && OrderMagicNumber() == MagicNumber)
              {
               Sell_trades_lot+=OrderLots();
              }

        }
     }
   Net_lot=MathAbs(Buy_trades_lot-Sell_trades_lot);
  }
//+------------------------------------------------------------------+
void Buy_Lot_Averaging()
  {

   Buy_LotSize=0;
   Buy_LotSize=NormalizeDouble((-(Buy_trades_profit)/(Buy_Averaging_points)/10)-Buy_trades_lot,2);
   if(Max_averaging_lot!=0 && Buy_LotSize>Max_averaging_lot)
      Buy_LotSize=Max_averaging_lot;


  }
//+------------------------------------------------------------------+
void Sell_Lot_Averaging()
  {

   Sell_LotSize=0;
   Sell_LotSize=NormalizeDouble((-(Sell_trades_profit)/(Sell_Averaging_points)/10)-Sell_trades_lot,2);
   if(Max_averaging_lot!=0 && Sell_LotSize>Max_averaging_lot)
      Sell_LotSize=Max_averaging_lot;

  }
//+------------------------------------------------------------------+
//New function to show errors
void Error_Handler()
  {
   int ErrorCode = GetLastError();
   string ErrDesc = ErrorDescription(ErrorCode);
   ErrAlert = StringConcatenate("Error Detected: No. ",ErrorCode," - \"",ErrDesc,"\"");
   Alert(ErrAlert);
  }
//+------------------------------------------------------------------+
int connectServer()
  {
   if(!IsConnected())
     {
      Print("Not connected to server");
      return 1;
     }
   return 0;
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
