-- ============================================================
-- SQL 2：门店每日收入质量明细
-- 分析周期：2017-08-01 ~ 2017-08-30
-- 输出：每店每日收入、折扣构成、客单价
-- ============================================================

SELECT
    c.dateName AS 日期,
    c.dimDateID AS 日期ID,
    s.shopCode AS 门店编码,
    s.name     AS 门店名称,
    s.areaName AS 大区名称,
    -- 收入结构
    SUM(i.AMT) + SUM(i.pAMT) + SUM(i.mpAMT) AS 吊牌总额,
    SUM(i.AMT)   AS 实际收入,
    SUM(i.pAMT)  AS 促销折扣额,
    SUM(i.mpAMT) AS 会员折扣额,
    -- 折扣率
    ROUND((SUM(i.pAMT) + SUM(i.mpAMT))
          / NULLIF(SUM(i.AMT) + SUM(i.pAMT) + SUM(i.mpAMT), 0) * 100, 2) AS 综合折扣率,
    -- 客户经济性
    SUM(i.QTY) AS 销售件数,
    h.订单数,
    ROUND(SUM(i.AMT) / NULLIF(h.订单数, 0), 2) AS 客单价
FROM fct_sales_item i
INNER JOIN dim_shop s ON i.dimShopID = s.dimShopID
INNER JOIN dim_date c ON i.dimDateID = c.dimDateID
INNER JOIN (
    -- 订单头表算订单数：一单一行，无需 DISTINCT
    SELECT dimShopID, dimDateID, COUNT(salesNo) AS 订单数
    FROM fct_sales
    WHERE dimDateID BETWEEN 20170801 AND 20170830
    GROUP BY dimShopID, dimDateID
) h ON h.dimShopID = i.dimShopID AND h.dimDateID = i.dimDateID
WHERE i.dimDateID BETWEEN 20170801 AND 20170830
GROUP BY c.dateName, c.dimDateID, s.shopCode, s.name, s.areaName, h.订单数
ORDER BY c.dimDateID, 实际收入 DESC;
