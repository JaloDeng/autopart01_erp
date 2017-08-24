-- *****************************************************************************************************
-- 创建存储过程 p_purch_in_by_bill, 以单据进仓存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_purch_in_by_bill`;
DELIMITER ;;
CREATE PROCEDURE `p_purch_in_by_bill`
(
		pid bigint(20) -- 采购单主键ID
	, sid int -- 仓位主键ID
	, uid bigint(20) -- 用户ID
)
BEGIN

	DECLARE aCheck, aReceive tinyint(4);
	DECLARE aid, aRoomId, aSupplierId bigint(20);
	DECLARE sTime, iTime datetime;
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

	-- 获取仓库主键ID
	SELECT s.roomId INTO aRoomId FROM ers_shelfattr s WHERE s.id = sid;
	-- 判断仓位是否存在
	IF isnull(aRoomId) THEN
		SET msg = concat('指定的仓位（编号：', sid,'）不存在，不能完成进仓！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 获取采购单信息
	SELECT pb.isCheck, pb.isReceive, pb.sncodeTime, pb.inTime, pb.supplierId 
	INTO aCheck, aReceive, sTime, iTime, aSupplierId
	FROM erp_purch_bil pb WHERE pb.id = pid;
	-- 判断单据状态是否可以进仓
	IF iTime > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单已经进仓完毕，不能完成统一进仓！';
	ELSEIF ISNULL(sTime) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单没有生码，不能完成统一进仓！';
	ELSEIF aReceive <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单仓库没有签收，不能完成统一进仓！';
	ELSEIF aCheck <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单没有审核通过，不能完成统一进仓！';
	ELSEIF ISNULL(aSupplierId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单没有供应商，不能完成统一进仓！';
	ELSEIF EXISTS(SELECT 1 FROM erp_purch_bil_intoqty pbi WHERE pbi.erp_purch_bil_id = pid LIMIT 1) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单已存在进仓记录，不能完成统一进仓！';
	ELSEIF EXISTS(SELECT 1 FROM erp_purch_detail pd INNER JOIN ers_packageattr p ON p.id = pd.ers_packageAttr_id WHERE pd.erp_purch_bil_id = pid AND p.degree > 1 LIMIT 1) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单存在配件是多层包装，不能完成统一进仓！';
	END IF;

	-- 写入进仓单
	insert into erp_purch_bil_intoqty(erp_purchDetail_snCode_id, erp_purch_bil_id, erp_purch_detail_id, goodsId, ers_packageattr_id
			, roomId, ers_shelfattr_id, packageQty, qty
			, inTime, inUserId, inEmpId, inEmpName)
	SELECT pds.id, pid, pd.id, pd.goodsId, pd.ers_packageAttr_id
			, aRoomId, sid, 1, pds.qty
			, NOW(), uid, aid, aName
	FROM erp_purch_detail pd
	INNER JOIN erp_purchdetail_sncode pds ON pds.erp_purch_detail_id = pd.id AND pds.goodsId = pd.goodsId
	WHERE pd.erp_purch_bil_id = pid;
	-- 判断是否操作成功
	IF ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '统一进仓时，写入进仓单失败！';
	END IF;
	
	-- 更新二维码表
	UPDATE erp_purchdetail_sncode pds INNER JOIN ers_shelfbook sb ON sb.ers_packageattr_id = pds.ers_packageattr_id AND sb.ers_shelfattr_id = sid
	SET pds.roomId = aRoomId, pds.ers_shelfattr_id = sid, pds.state = 1, pds.ers_shelfbook_id = sb.id
	WHERE pds.erp_purch_bil_id = pid;
	-- 判断是否操作成功
	IF ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '统一进仓时，更新二维码表状态失败！';
	END IF;

	-- 更新采购单、明细进仓信息
	UPDATE erp_purch_detail pd INNER JOIN erp_purch_bil pb ON pb.id = pd.erp_purch_bil_id
	SET pd.inTime = NOW(), pd.lastModifiedId = uid
		, pb.inTime = NOW(), pb.lastModifiedId = uid, pb.inUserId = uid, pb.inEmpId = aid, pb.inEmpName = aName
	WHERE pb.id = pid;

	-- 更新供应商价格列表价格信息
	IF EXISTS(SELECT 1 FROM erp_suppliersgoods sg INNER JOIN erp_purch_detail pd ON sg.crm_suppliers_id = aSupplierId AND sg.ers_packageAttr_id = pd.ers_packageAttr_id 
		WHERE pd.erp_purch_bil_id = pid LIMIT 1) THEN
			-- 更新价格
			UPDATE erp_suppliersgoods sg INNER JOIN erp_purch_detail pd ON sg.crm_suppliers_id = aSupplierId AND sg.ers_packageAttr_id = pd.ers_packageAttr_id 
			SET sg.newPrice = pd.packagePrice
				, sg.minPrice = IF(IFNULL(sg.minPrice,0) = 0, pd.packagePrice, IF(sg.minPrice < pd.packagePrice, sg.minPrice, pd.packagePrice))
				, sg.maxPrice = IF(IFNULL(sg.maxPrice,0) = 0, pd.packagePrice, IF(sg.maxPrice > pd.packagePrice, sg.maxPrice, pd.packagePrice))
			WHERE pd.erp_purch_bil_id = pid;
	END IF;
	IF EXISTS(SELECT 1 FROM erp_purch_detail pd LEFT JOIN erp_suppliersgoods sg ON sg.crm_suppliers_id = aSupplierId AND sg.ers_packageAttr_id = pd.ers_packageAttr_id
		WHERE pd.erp_purch_bil_id = pid AND ISNULL(sg.crm_suppliers_id) LIMIT 1) THEN
			-- 写入价格
			INSERT INTO erp_suppliersgoods(crm_suppliers_id, ers_packageAttr_id, goodsId, newPrice, minPrice, maxPrice)
			SELECT aSupplierId, pd.ers_packageAttr_id, pd.goodsId, pd.packagePrice, pd.packagePrice, pd.packagePrice
			FROM erp_purch_detail pd LEFT JOIN erp_suppliersgoods sg ON sg.crm_suppliers_id = aSupplierId AND sg.ers_packageAttr_id = pd.ers_packageAttr_id
			WHERE pd.erp_purch_bil_id = pid AND ISNULL(sg.crm_suppliers_id);
			IF ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功新增供应商-包裹的最新进价、最低进价、最高进价！';
			END IF;
	END IF;

	-- 更新商品包装表价格
	UPDATE ers_packageattr p INNER JOIN erp_purch_detail pd ON pd.ers_packageAttr_id = p.id AND p.degree = 1
	SET p.newSupplierId = aSupplierId, p.newPrice = pd.packagePrice
		, p.minPrice = IF(IFNULL(p.minPrice,0) = 0, pd.packagePrice, IF(p.minPrice < pd.packagePrice, p.minPrice, pd.packagePrice))
		, p.maxPrice = IF(IFNULL(p.maxPrice,0) = 0, pd.packagePrice, IF(p.maxPrice > pd.packagePrice, p.maxPrice, pd.packagePrice))
	WHERE pd.erp_purch_bil_id = pid;

	-- 判断是否存在销售明细并更改可以出仓标记位
	IF EXISTS(SELECT 1 FROM erp_purch_detail pd INNER JOIN erp_sales_detail sd ON sd.id = pd.erp_sales_detail_id
		WHERE pd.erp_purch_bil_id = pid AND sd.isEnough = 0 LIMIT 1) THEN
			-- 修改相应销售明细isEnough = 1
			UPDATE erp_sales_detail sd INNER JOIN erp_purch_detail pd ON pd.erp_sales_detail_id = sd.id
			SET sd.isEnough = 1, sd.lastModifiedId = uid
			WHERE pd.erp_purch_bil_id = pid AND sd.isEnough = 0;
			IF ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '入库完毕，未能成功修改相应销售明细可以出仓标志！';
			END IF;
	END IF;

	-- 判断是否存在销售单并更改可以出仓标记位(是否全部采购单已进仓)
	IF NOT EXISTS(SELECT 1 FROM erp_purch_bil pb1 INNER JOIN erp_purch_bil pb2 ON pb2.erp_vendi_bil_id = pb1.erp_vendi_bil_id
		WHERE pb1.id = pid AND ISNULL(pb2.inTime) LIMIT 1) THEN
			IF EXISTS(SELECT 1 FROM erp_vendi_bil v INNER JOIN erp_purch_bil p ON p.erp_vendi_bil_id = v.id WHERE p.id = pid AND v.isSubmit = 0) THEN 
				-- 修改相应销售单的可以出仓标志isSubmit = 1
				UPDATE erp_vendi_bil b INNER JOIN erp_purch_bil p ON b.id = p.erp_vendi_bil_id
					SET b.isSubmit = 1, b.lastModifiedId = uid
				WHERE p.id = pid;
				IF ROW_COUNT() = 0 THEN
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '入库完毕，未能成功修改相应销售单可以出仓标志！';
				END IF;
			END IF;
	END IF;
	
	COMMIT;

END;;
DELIMITER ;