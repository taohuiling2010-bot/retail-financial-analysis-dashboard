-- ============================================================
-- SQL 7：门店商品覆盖校验
-- 全量校验各门店在分析期内的零销售 SKU 数,用于确认有效门店范围
-- ============================================================

SELECT s.name AS 门店, COUNT(*) AS 零销售SKU数
FROM dim_shop s
CROSS JOIN dim_goods g
LEFT JOIN (
    SELECT DISTINCT dimShopID, goodsID
    FROM fct_sales_item
    WHERE dimDateID BETWEEN 20170801 AND 20170830
) sa ON sa.dimShopID = s.dimShopID AND sa.goodsID = g.dimGoodsID
WHERE sa.goodsID IS NULL
  AND g.name NOT LIKE '%优惠券%' AND g.name NOT LIKE '%赠券%' AND g.name NOT LIKE '%代金券%'
GROUP BY s.name;