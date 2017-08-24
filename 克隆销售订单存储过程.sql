-- *****************************************************************************************************
-- 创建存储过程 p_copy_vendi_bil, 克隆销售订单存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_copy_vendi_bil`;
DELIMITER ;;
CREATE PROCEDURE `p_copy_vendi_bil`
(
		aid bigint(20) -- 要克隆的单据主键ID
	, tid int -- 单据类型，1：销售订单，2：采购订单
	, uid bigint(20) -- 用户ID
)
BEGIN

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

	START TRANSACTION;

	IF tid = 1 THEN -- 销售订单
		-- 新增销售订单
		INSERT INTO erp_vendi_bil(customerId, creatorId, lastModifiedId, erc$telgeo_contact_id)
		SELECT vb.customerId, uid, uid, vb.erc$telgeo_contact_id
		FROM erp_vendi_bil vb WHERE vb.id = aid;

		-- 判断是否新增成功
		IF ROW_COUNT() <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功重新开单主表！';
		END IF;

		-- 获取主键编ID
		SET @lid = LAST_INSERT_ID();

		-- 新增销售明细
		INSERT INTO erp_sales_detail(erp_vendi_bil_id, ers_packageAttr_id, goodsId, supplierId, packageQty, packagePrice, price, salesPackagePrice, lastModifiedId)
		SELECT @lid, sd.ers_packageAttr_id, sd.goodsId, sd.supplierId, sd.packageQty, sd.packagePrice, sd.price, sd.salesPackagePrice, uid
		FROM erp_sales_detail sd WHERE sd.erp_vendi_bil_id = aid;

		-- 判断是否新增成功
		IF ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功重新开单明细！';
		END IF;
	
	ELSEIF tid = 2 THEN
		-- 新增采购订单
		INSERT INTO erp_purch_bil(supplierId, lastModifiedId, erc$telgeo_contact_id)
		SELECT pb.supplierId, uid, pb.erc$telgeo_contact_id
		FROM erp_purch_bil pb WHERE pb.id = aid;

		-- 判断是否新增成功
		IF ROW_COUNT() <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功重新开单主表！';
		END IF;

		-- 获取主键ID
		SET @lid = LAST_INSERT_ID();

		-- 新增采购明细
		INSERT INTO erp_purch_detail(erp_purch_bil_id, goodsId, supplierId, ers_packageAttr_id, packageQty, packagePrice, lastModifiedId)
		SELECT @lid, pd.goodsId, pd.supplierId, pd.ers_packageAttr_id, pd.packageQty, pd.packagePrice, uid
		FROM erp_purch_detail pd WHERE pd.erp_purch_bil_id = aid;

		-- 判断是否新增成功
		IF ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功重新开单明细！';
		END IF;

	END IF;

	COMMIT;

END;;
DELIMITER ;