//+------------------------------------------------------------------+
//|							刘松 ok.mq4 |
//|								刘松 |
//|				  希望大家珍惜我的劳动成果！转载时务必通知我！|
//|                 liusongwh@qq.com qq:569638390 |
//+------------------------------------------------------------------+
#property copyright	"刘松"
#property link		"liusongwh@qq.com qq:569638390"
extern string	声明 = "希望大家珍惜我的劳动成果！转载时务必通知我！我保留一切追究的权利";

// ma()的周期.
extern string	平均周期计算 = " 平均周期计算 ";
extern double	m = 15; 
extern double	n = 180;
extern int	SDL1_period = 100;
extern int	SDL1_method = 3;
extern int	SDL1_price = 0;

// 用点差, 滤掉无效的杂波.
extern string	关键去杂波参数 = "时间周期越小，取值相应变小";
extern double	bodong = 8.8;

// ma()的计算公式.
extern string	MA方法 = "0 sma 1 ema 2 smma 3 lwma";
extern double	d = 1 ;

// 交易定单的信息.
extern string	交易设定 = "交易设定" ;
extern double	Lot = 0.1;
extern double	slippage = 3;
extern int	maxlots = 1;
extern int	SL = 2000;
extern int	TP = 2000;
extern int	dindan_13_5 = 55356;


// 允许交易的标志. 0:允许; 1:禁止.
int  jy=0;

// 当前图表的点值.
double g_point;


int init() {
	// 设置隐藏智能交易使用的指标.
	HideTestIndicators(TRUE);
	// 当前图表的点值
	if (Point == 0.00001)
		g_point = 0.0001;
	else if (Point == 0.001)
		g_point = 0.01;
	else
		g_point = Point;

	return(0);
}

int start() {
	double d1_main, d1_sign, i, CurrEMA1Up_1, CurrEMA1Dn_1, CurrEMA1Up_2, CurrEMA1Dn_2, buy, sell, Lots, zijin, QQE_1, QQE_2, d1_main_2, d1_sign_2,
		d1_main_3, d1_sign_3, d1_main_4, d1_sign_4, d1_main_5, d1_sign_5, d1_main_6, d1_sign_6, chazhi_2, chazhi_3;

	// 最进6根k线的 ma(5, 13)值.
	d1_main = iMA(NULL, 0, m, 0, d, 0, 1);
	d1_sign = iMA(NULL, 0, n, 0, d, 0, 1);
	d1_main_2 = iMA(NULL, 0, m, 0, d, 0, 2);
	d1_sign_2 = iMA(NULL, 0, n, 0, d, 0, 2);
	d1_main_3 = iMA(NULL, 0, m, 0, d, 0, 3);
	d1_sign_3 = iMA(NULL, 0, n, 0, d, 0, 3);
	d1_main_4 = iMA(NULL, 0, m, 0, d, 0, 4);
	d1_sign_4 = iMA(NULL, 0, n, 0, d, 0, 4);
	d1_main_5 = iMA(NULL, 0, m, 0, d, 0, 5);
	d1_sign_5 = iMA(NULL, 0, n, 0, d, 0, 5);
	d1_main_6 = iMA(NULL, 0, m, 0, d, 0, 6);
	d1_sign_6 = iMA(NULL, 0, n, 0, d, 0, 6);


	// 计算指定的客户指标并且退回它的值. 客户指标完成程序名称: "###QQE_Alert_MTF_v2###".
	// "Slope Direction Line"中, 最进1根k线的0#, 1#画线的值. 
	// 函数的参数: (2, 0).
	QQE_1 = iCustom(Symbol(), PERIOD_D1, "###QQE_Alert_MTF_v2###", 2, 0, 0, 0);
	QQE_2 = iCustom(Symbol(), PERIOD_D1, "###QQE_Alert_MTF_v2###", 2, 0, 1, 0);

	// 计算指定的客户指标并且退回它的值. 客户指标完成程序名称: "Slope Direction Line".
	// "Slope Direction Line"中, 最进2根k线的0#画线的值.
	// 函数的参数: (SDL1_period, SDL1_method, SDL1_price).
	CurrEMA1Up_1 = iCustom(NULL, 0, "Slope Direction Line", SDL1_period, SDL1_method, SDL1_price, 0,0);
	CurrEMA1Up_2 = iCustom(NULL, 0, "Slope Direction Line", SDL1_period, SDL1_method, SDL1_price, 0,1);
	// "Slope Direction Line"中, 最进2根k线的1#画线的值.
	CurrEMA1Dn_1 = iCustom(NULL, 0, "Slope Direction Line", SDL1_period, SDL1_method, SDL1_price, 1,0);
	CurrEMA1Dn_2 = iCustom(NULL, 0, "Slope Direction Line", SDL1_period, SDL1_method, SDL1_price, 1,1);



	buy = CurrEMA1Up_1 - CurrEMA1Up_2;
	sell = CurrEMA1Dn_2 - CurrEMA1Dn_1; 

	// ma(5)加速上升/下降.
	chazhi_2 = (d1_main + d1_main_2+d1_main_3) - (d1_main_4 + d1_main_5 + d1_main_6);

                 
	if (chazhi_2 > 0)
		// ma(5)加速下降.
		chazhi_3=chazhi_2;
	else if (chazhi_2 < 0)
		// ma(5)加速下降.
		chazhi_3 = 0 - chazhi_2;


	// 如果未平定单的交易方向与ma(5)的走势不同, 平仓.
	int	total = OrdersTotal();
	if (total > 0 )
		for (i=OrdersTotal()-1; i >= 0; i--) {
			if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
				break;
			if (OrderMagicNumber() == dindan_13_5) {
				if (OrderType() == OP_BUY)
					if ((sell > 0 && d1_main < d1_sign) || chazhi_3 < bodong * g_point) {
						OrderClose(OrderTicket(), OrderLots(), Bid, slippage * g_point, White);
						Sleep(5000);
					}

				if (OrderType() == OP_SELL)
					if ((buy > 0 &&  d1_main > d1_sign) || chazhi_3 < bodong * g_point) {
						OrderClose(OrderTicket(), OrderLots(), Ask, slippage * g_point, White);
						Sleep(5000);
					}
			}
		}

	// 根据可用资金的大小, 计算交易数量.
	zijin = AccountFreeMargin();
	if (zijin <= 2500)
		Lots = Lot;
	else if (zijin > 2500)
		Lots = NormalizeDouble((zijin/25000), 1);

	// 如果ma(5, 13)的金叉, jy=0.
	if (d1_main > d1_sign && d1_main_3 < d1_sign_3)
		jy = 0;

	// 开多单.
	if (jy == 0 && QQE_1 > QQE_2 && buy > 0 && total < maxlots && d1_main > d1_sign && chazhi_3 > bodong * g_point) {
		OrderSend(Symbol(), OP_BUY, Lots, Ask, slippage, Ask - SL * g_point, Ask + TP * g_point, "BUY", dindan_13_5, 0, Red);
		jy = 1;
	}

	// 如果ma(5, 13)的死叉, jy=0.
	if (d1_main < d1_sign && d1_main_3 > d1_sign_3 )
		jy = 0;

	// 开空单.
	if (jy == 0 && QQE_1 < QQE_2 && sell > 0 && total < maxlots && d1_main < d1_sign && chazhi_3 > bodong * g_point) {
		jy = 1;
		OrderSend(Symbol(), OP_SELL, Lots, Bid, slippage, Bid + SL * g_point, Bid - TP * g_point, "SELL", dindan_13_5, 0, Green);
	}  

	return(0);
}
//+------------------------------------------------------------------+