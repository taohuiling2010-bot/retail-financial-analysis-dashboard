============================================================
SQL 3：门店当日 vs 昨日收入与折扣对比
当日：2017-08-30  昨日：2017-08-29
============================================================

SELECT
    b.shopCode AS 门店编码,
    b.name     AS 门店名称,
    b.areaCode AS 大区编码,
    b.areaName AS 大区名称,
    -- 当日
    SUM(CASE WHEN a.dimDateID = 20170830 THEN a.AMT ELSE 0 END) AS 实际收入,
    SUM(CASE WHEN a.dimDateID = 20170830 THEN a.pAMT ELSE 0 END) AS 促销折扣额,
    SUM(CASE WHEN a.dimDateID = 20170830 THEN a.mpAMT ELSE 0 END) AS 会员折扣额,
    SUM(CASE WHEN a.dimDateID = 20170830 THEN a.QTY ELSE 0 END) AS 销售件数,
    COUNT(DISTINCT CASE WHEN a.dimDateID = 20170830 THEN a.salesNo END) AS 订单数,
    ROUND((SUM(CASE WHEN a.dimDateID = 20170830 THEN a.pAMT ELSE 0 END)
         + SUM(CASE WHEN a.dimDateID = 20170830 THEN a.mpAMT ELSE 0 END))
        / NULLIF(SUM(CASE WHEN a.dimDateID = 20170830 THEN a.AMT ELSE 0 END)
               + SUM(CASE WHEN a.dimDateID = 20170830 THEN a.pAMT ELSE 0 END)
               + SUM(CASE WHEN a.dimDateID = 20170830 THEN a.mpAMT ELSE 0 END), 0) * 100, 2) AS 综合折扣率,
    -- 昨日
    SUM(CASE WHEN a.dimDateID = 20170829 THEN a.AMT ELSE 0 END) AS 昨日实际收入,
    SUM(CASE WHEN a.dimDateID = 20170829 THEN a.pAMT ELSE 0 END) AS 昨日促销折扣额,
    SUM(CASE WHEN a.dimDateID = 20170829 THEN a.mpAMT ELSE 0 END) AS 昨日会员折扣额,
    COUNT(DISTINCT CASE WHEN a.dimDateID = 20170829 THEN a.salesNo END) AS 昨日订单数,
    -- 日环比
    ROUND((SUM(CASE WHEN a.dimDateID = 20170830 THEN a.AMT ELSE 0 END)
         - SUM(CASE WHEN a.dimDateID = 20170829 THEN a.AMT ELSE 0 END))
        / NULLIF(SUM(CASE WHEN a.dimDateID = 20170829 THEN a.AMT ELSE 0 END), 0) * 100, 2) AS 收入日环比
FROM fct_sales_item a
INNER JOIN dim_shop b ON a.dimShopID = b.dimShopID
WHERE a.dimDateID IN (20170829, 20170830)
GROUP BY b.shopCode, b.name, b.areaCode, b.areaName
ORDER BY 实际收入 DESC;
