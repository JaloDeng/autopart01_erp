-- *****************************************************************************************************
-- 创建存储过程 p_vendi_stock_by_bill, 以单据进仓存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_vendi_stock_by_bill`;
DELIMITER ;;
CREATE PROCEDURE `p_vendi_stock_by_bill`
(
		vid bigint(20) -- 销售单主键ID
	, sid int -- 仓位主键ID
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

	-- 获取仓库主键ID
	SELECT s.roomId INTO aRoomId FROM ers_shelfattr s WHERE s.id = sid;
	-- 判断仓位是否存在
	IF isnull(aRoomId) THEN
		SET msg = concat('指定的仓位（编号：', sid,'）不存在，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 获取销售订单信息
	SELECT vb.isCheck, vb.isSubmit, vb.outTime, vb.stockTime 
	INTO aCheck, aSubmit, oTime, sTime
	FROM erp_vendi_bil vb WHERE vb.id = vid;
	-- 判断单据状态是否可以备货
	IF oTime > 0 THEN
		SET msg = concat('销售单（编号：', vid,'）已完成出仓，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF sTime > 0 THEN
		SET msg = concat('销售单（编号：', vid,'）已完成备货，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aSubmit <> 1 THEN
		SET msg = concat('销售单（编号：', vid,'）未完成进仓，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck <> 1 THEN
		SET msg = concat('销售单（编号：', vid,'）没审核通过或已归档，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF NOT EXISTS(SELECT 1 FROM erp_purch_bil pb WHERE pb.erp_vendi_bil_id = vid) THEN
		SET msg = concat('销售单（编号：', vid,'）直接库存出库，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_vendi_bil_stockqty vbs WHERE vbs.erp_vendi_bil_id = vid LIMIT 1) THEN
		SET msg = concat('销售单（编号：', vid,'）已存在备货记录，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_sales_detail sd INNER JOIN ers_packageattr p ON p.id = sd.ers_packageAttr_id WHERE sd.erp_vendi_bil_id = vid AND p.degree > 1 LIMIT 1) THEN
		SET msg = concat('销售单（编号：', vid,'）存在配件是多层包装，不能完成备货！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_vendi_bil vb INNER JOIN erp_purch_bil pb ON pb.erp_vendi_bil_id = vb.id
		INNER JOIN erp_purchdetail_sncode pds ON pds.erp_purch_bil_id = pb.id AND pds.state <> 1 WHERE vb.id = vid LIMIT 1) THEN
			SET msg = concat('销售单（编号：', vid,'）对应配件存在已出仓或未进仓情况，不能完成备货！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF EXISTS(SELECT 1 FROM erp_vendi_bil vb INNER JOIN erp_purch_bil pb ON pb.erp_vendi_bil_id = vb.id
		INNER JOIN erp_purchdetail_sncode pds ON pds.erp_purch_bil_id = pb.id AND pds.stockState <> 0 WHERE vb.id = vid LIMIT 1) THEN
			SET msg = concat('销售单（编号：', vid,'）对应配件存在已备货情况，不能完成备货！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 写入备货单
	INSERT INTO erp_vendi_bil_stockqty(erp_purchdetail_sncode_id, erp_vendi_bil_id, erp_sales_detail_id
		, goodsId, ers_packageattr_id, roomId, ers_shelfattr_id, packageQty, qty
		, stockTime, stockUserId, stockEmpId, stockEmpName)
	SELECT pds.id, sd.erp_vendi_bil_id, sd.id
		, pds.goodsId, pds.ers_packageattr_id, pds.roomId, pds.ers_shelfattr_id, 1, pds.qty
		, NOW(), uid, aid, aName
	FROM erp_sales_detail sd 
	INNER JOIN erp_purch_detail pd ON pd.erp_sales_detail_id = sd.id
	INNER JOIN erp_purchdetail_sncode pds ON pds.erp_purch_detail_id = pd.id
	WHERE sd.erp_vendi_bil_id = vid;
	-- 判断是否操作成功
	IF ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '统一备货时，写入备货失败！';
	END IF;

	-- 更新二维码表备货标记位
	UPDATE erp_purchdetail_sncode pds INNER JOIN erp_purch_detail pd ON pd.id = pds.erp_purch_detail_id
	INNER JOIN erp_sales_detail sd ON sd.id = pd.erp_sales_detail_id
	SET pds.stockState = 1
	WHERE sd.erp_vendi_bil_id = vid;
	-- 判断是否操作成功
	IF ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '统一进仓时，更新二维码表状态失败！';
	END IF;

	-- 更新销售单、销售明细备货时间信息
	UPDATE erp_vendi_bil vb INNER JOIN erp_sales_detail sd ON sd.erp_vendi_bil_id = vb.id
	SET vb.stockUserId = uid, vb.stockEmpId = aid, vb.stockEmpName = aName, vb.stockTime = NOW()
		, vb.lastModifiedId = uid, vb.lastModifiedEmpId = aid, vb.lastModifiedEmpName = aName, vb.lastModifiedBy = aUserName, vb.lastModifiedDate = NOW()
		, sd.stockTime = NOW(), sd.lastModifiedId = uid
	WHERE vb.id = vid;
	
	COMMIT;

END;;
DELIMITER ;