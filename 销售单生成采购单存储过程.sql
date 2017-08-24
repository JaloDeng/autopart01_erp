-- *****************************************************************************************************
-- 创建存储过程 p_vendi_purch, 销售单生成采购单存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_vendi_purch`;
DELIMITER ;;
CREATE PROCEDURE `p_vendi_purch`(aid bigint(20))
BEGIN

	DECLARE msg VARCHAR(1000);
	DECLARE lid BIGINT(20);

	-- 生成采购单主表，与销售单1对1
	INSERT INTO erp_purch_bil(erp_vendi_bil_id, erp_inquiry_bil_id, priceSumCome, creatorId, createdDate
		, createdBy, empId, empName, memo, inquiryCode, needTime
		, lastModifiedDate, lastModifiedId, lastModifiedEmpId, lastModifiedEmpName, lastModifiedBy)
	SELECT a.id, a.erp_inquiry_bil_id, SUM(b.amt), a.checkUserId, now()
		, a.lastModifiedBy, a.checkEmpId, a.checkEmpName, concat('销售订单审核库存不足自动转入。'), a.inquiryCode, a.needTime
		, now(), a.lastModifiedId, a.lastModifiedEmpId, a.lastModifiedEmpName, a.lastModifiedBy
	FROM erp_vendi_bil a 
	INNER JOIN erp_sales_detail b ON b.erp_vendi_bil_id = a.id
	where a.id = aid AND b.isEnough = 0
	;
	if ROW_COUNT() <> 1 THEN
		set msg = concat('销售单（编号：', aid,'）转采购单时，未能生成采购单主表!');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 采购单主表ID
	SET lid = LAST_INSERT_ID();
	
	-- 生成采购订单明细
	insert into erp_purch_detail(erp_purch_bil_id, erp_vendi_bil_id, erp_sales_detail_id, supplierId
		, goodsId, ers_packageAttr_id, packageUnit, packageQty, packagePrice
		, qty, price, amt, createdDate, updatedDate, lastModifiedDate
		, lastModifiedId, lastModifiedEmpId, lastModifiedEmpName, lastModifiedBy)
	select lid, aid, a.id, a.supplierId
		, a.goodsId, a.ers_packageAttr_id, a.packageUnit, a.packageQty, a.packagePrice
		, a.qty, a.price, a.amt, now(), now(), now()
		, b.lastModifiedId, b.lastModifiedEmpId, b.lastModifiedEmpName, b.lastModifiedBy
	from erp_sales_detail a 
	INNER JOIN erp_vendi_bil b on a.erp_vendi_bil_id = b.id
	where a.erp_vendi_bil_id = aid and a.isEnough = 0 
	;
	if ROW_COUNT() = 0 THEN
		set msg = concat('销售单（编号：', aid,'）转采购单时，未能生成采购单明细!');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
END;;
DELIMITER ;