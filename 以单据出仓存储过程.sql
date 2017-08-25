-- *****************************************************************************************************
-- 创建存储过程 p_vendi_out_by_bill, 以单据出仓存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_vendi_out_by_bill`;
DELIMITER ;;
CREATE PROCEDURE `p_vendi_out_by_bill`
(
		vid bigint(20) -- 销售单主键ID
	, uid bigint(20) -- 用户ID
)
BEGIN

	DECLARE aCheck, aSubmit tinyint(4);
	DECLARE aid, aRoomId bigint(20);
	DECLARE oTime, sTime datetime;
	DECLARE aName, aUserName varchar(100);
	DECLARE msg VARCHAR(1000);

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

	START TRANSACTION;

	-- 获取用户相关信息
	call p_get_userInfo(uid, aid, aName, aUserName);

	-- 获取销售订单信息
	SELECT vb.isCheck, vb.isSubmit, vb.outTime, vb.stockTime 
	INTO aCheck, aSubmit, oTime, sTime
	FROM erp_vendi_bil vb WHERE vb.id = vid;
	-- 判断单据状态是否可以出仓
	IF oTime > 0 THEN
		SET msg = concat('销售单（编号：', vid,'）已完成出仓，不能重复出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(sTime) THEN
		SET msg = concat('销售单（编号：', vid,'）没有完成备货，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck <> 1 THEN
		SET msg = concat('销售单（编号：', vid,'）没审核通过或已归档，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF NOT EXISTS(SELECT 1 FROM erp_purch_bil pb WHERE pb.erp_vendi_bil_id = vid) THEN
		SET msg = concat('销售单（编号：', vid,'）直接库存销售，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_vendi_bil_goutqty vbg WHERE vbg.erp_vendi_bil_id = vid LIMIT 1) THEN
		SET msg = concat('销售单（编号：', vid,'）已存在出仓记录，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_sales_detail sd INNER JOIN ers_packageattr p ON p.id = sd.ers_packageAttr_id WHERE sd.erp_vendi_bil_id = vid AND p.degree > 1 LIMIT 1) THEN
		SET msg = concat('销售单（编号：', vid,'）存在配件是多层包装，不能完成出仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_vendi_bil vb INNER JOIN erp_purch_bil pb ON pb.erp_vendi_bil_id = vb.id
		INNER JOIN erp_purchdetail_sncode pds ON pds.erp_purch_bil_id = pb.id AND pds.state <> 1 WHERE vb.id = vid LIMIT 1) THEN
			SET msg = concat('销售单（编号：', vid,'）对应配件存在已出仓或未进仓情况，不能完成出仓！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_vendi_bil vb INNER JOIN erp_purch_bil pb ON pb.erp_vendi_bil_id = vb.id
		INNER JOIN erp_purchdetail_sncode pds ON pds.erp_purch_bil_id = pb.id AND pds.stockState <> 1 WHERE vb.id = vid LIMIT 1) THEN
			SET msg = concat('销售单（编号：', vid,'）对应配件存在没有备货情况，不能完成出仓！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_sales_detail sd INNER JOIN erp_purch_detail pd ON pd.erp_sales_detail_id = sd.id
		INNER JOIN erp_purchdetail_sncode pds ON pds.erp_purch_detail_id = pd.id
		INNER JOIN erp_goods_cancel_detail gcd ON gcd.erp_purchDetail_snCode_id = pds.id WHERE sd.erp_vendi_bil_id = vid LIMIT 1) THEN
			SET msg = concat('销售单（编号：', vid,'）对应配件存在核销记录，不能完成出仓！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_sales_detail sd INNER JOIN erp_purch_detail pd ON pd.erp_sales_detail_id = sd.id
		INNER JOIN erp_purchdetail_sncode pds ON pds.erp_purch_detail_id = pd.id
		INNER JOIN erp_vendi_bil_stockqty vbs ON vbs.erp_purchDetail_snCode_id = pds.id WHERE sd.erp_vendi_bil_id = vid LIMIT 1) THEN
			SET msg = concat('销售单（编号：', vid,'）对应配件存在别的备货单中，不能完成出仓！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
 	END IF;

	-- 写入出仓单
	INSERT INTO erp_vendi_bil_goutqty(erp_purchdetail_sncode_id, erp_vendi_bil_id, erp_sales_detail_id
		, goodsId, ers_packageattr_id, degree, roomId, ers_shelfattr_id, packageQty, qty
		, outTime, outUserId, outEmpId, outEmpName)
	SELECT pds.id, vid, sd.id
		, pds.goodsId, pds.ers_packageattr_id, pds.degree, pds.roomId, pds.ers_shelfattr_id, 1, pds.qty
		, NOW(), uid, aid, aName
	FROM erp_sales_detail sd INNER JOIN erp_purch_detail pd ON pd.erp_vendi_bil_id = sd.id
	INNER JOIN erp_purchdetail_sncode pds ON pds.erp_purch_detail_id = pd.id
	WHERE sd.erp_vendi_bil_id = vid;
	-- 判断是否操作成功
	IF ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '统一出仓时，写入出仓单失败！';
	END IF;

	-- 更新二维码表出仓标记位
	UPDATE erp_purchdetail_sncode pds INNER JOIN erp_purch_detail pd ON pd.id = pds.erp_purch_detail_id
	INNER JOIN erp_sales_detail sd ON sd.id = pd.erp_sales_detail_id
	SET pds.state = -1, pds.ers_shelfbook_id = -1
	WHERE sd.erp_vendi_bil_id = vid;
	-- 判断是否操作成功
	IF ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '统一进仓时，更新二维码表状态失败！';
	END IF;

	-- 更新销售单、销售明细备货时间信息
	UPDATE erp_vendi_bil vb INNER JOIN erp_sales_detail sd ON sd.erp_vendi_bil_id = vb.id
	SET vb.outUserId = uid, vb.outEmpId = aid, vb.outEmpName = aName, vb.outTime = NOW()
		, vb.lastModifiedId = uid, vb.lastModifiedEmpId = aid, vb.lastModifiedEmpName = aName, vb.lastModifiedBy = aUserName, vb.lastModifiedDate = NOW()
		, sd.outTime = NOW(), sd.lastModifiedId = uid
	WHERE vb.id = vid;

	-- 更新供应商价格列表价格信息
	IF EXISTS(SELECT 1 FROM erp_sales_detail sd INNER JOIN erp_purch_detail pd ON pd.erp_sales_detail_id = sd.id 
		INNER JOIN erp_suppliersgoods sg ON sg.crm_suppliers_id = pd.supplierId AND sg.ers_packageAttr_id = pd.ers_packageAttr_id
		WHERE sd.erp_vendi_bil_id = vid LIMIT 1) THEN
			-- 更新价格
			UPDATE erp_suppliersgoods sg INNER JOIN erp_purch_detail pd ON sg.crm_suppliers_id = pd.supplierId AND sg.ers_packageAttr_id = pd.ers_packageAttr_id
			INNER JOIN erp_sales_detail sd ON sd.id = pd.erp_sales_detail_id
			SET sg.newSalesPrice = sd.salesPackagePrice
				, sg.minSalesPrice = IF(IFNULL(sg.minSalesPrice,0) = 0, sd.salesPackagePrice, IF(sg.minSalesPrice < sd.salesPackagePrice, sg.minSalesPrice, sd.salesPackagePrice))
				, sg.maxSalesPrice = IF(IFNULL(sg.maxSalesPrice,0) = 0, sd.salesPackagePrice, IF(sg.maxSalesPrice > sd.salesPackagePrice, sg.maxSalesPrice, sd.salesPackagePrice))
			WHERE pd.erp_purch_bil_id = pid;
	END IF;
	IF EXISTS(SELECT 1 FROM erp_sales_detail sd INNER JOIN erp_purch_detail pd ON pd.erp_sales_detail_id = sd.id
		LEFT JOIN erp_suppliersgoods sg ON sg.crm_suppliers_id = pd.supplierId AND sg.ers_packageAttr_id = pd.ers_packageAttr_id
		WHERE sd.erp_vendi_bil_id = vid AND ISNULL(sg.crm_suppliers_id) LIMIT 1) THEN
			-- 写入价格
			INSERT INTO erp_suppliersgoods(crm_suppliers_id, ers_packageAttr_id, goodsId, newSalesPrice, minSalesPrice, maxSalesPrice)
			SELECT pd.supplierId, sd.ers_packageAttr_id, sd.goodsId, sd.salesPackagePrice, sd.salesPackagePrice , sd.salesPackagePrice
			FROM erp_sales_detail sd INNER JOIN erp_purch_detail pd ON pd.erp_sales_detail_id = sd.id
			LEFT JOIN erp_suppliersgoods sg ON sg.crm_suppliers_id = pd.supplierId AND sg.ers_packageAttr_id = pd.ers_packageAttr_id
			WHERE sd.erp_vendi_bil_id = vid AND ISNULL(sg.crm_suppliers_id);
			IF ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功新增供应商-包裹的最新售价、最低售价、最高售价！';
			END IF;
	END IF;

	-- 更新商品包装表价格
	UPDATE ers_packageattr p INNER JOIN erp_sales_detail sd ON sd.ers_packageAttr_id = p.id AND p.degree = 1
	SET p.newSalesPrice = sd.salesPackagePrice
		, p.minSalesPrice = IF(IFNULL(p.minSalesPrice,0) = 0, sd.salesPackagePrice, IF(p.minSalesPrice < sd.salesPackagePrice, p.minSalesPrice, sd.salesPackagePrice))
		, p.maxSalesPrice = IF(IFNULL(p.maxSalesPrice,0) = 0, sd.salesPackagePrice, IF(p.maxSalesPrice > sd.salesPackagePrice, p.maxSalesPrice, sd.salesPackagePrice))
	WHERE sd.erp_vendi_bil_id = vid;

	-- 记录操作
	INSERT INTO erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	SELECT vid, 'out', uid, aid, aName, aUserName, '统一出仓';
	
	COMMIT;

END;;
DELIMITER ;