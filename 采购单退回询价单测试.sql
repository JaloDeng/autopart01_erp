CALL p_purch_vendi_back(3, 12);

-- -- 删除销售发货单
-- DELETE FROM erp_vendi_deliv WHERE erp_vendi_bil_id = 2;
-- -- 删除销售流程状态表
-- DELETE FROM erp_vendi_bilwfw WHERE billId = 2;
-- -- 删除销售明细表
-- DELETE FROM erp_sales_detail WHERE erp_vendi_bil_id = 2;
-- -- 删除销售单
-- DELETE FROM erp_vendi_bil WHERE id = 2;
-- -- 修改询价单状态
-- UPDATE erp_inquiry_bil a SET a.ischeck = 0 WHERE a.id = 2;