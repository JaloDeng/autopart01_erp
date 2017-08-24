-- *****************************************************************************************************
-- 创建存储过程 p_purch_back_to_vendi, 采购单退回销售单存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_purch_back_to_vendi`;
DELIMITER ;;
CREATE PROCEDURE `p_purch_back_to_vendi`
(
		aid bigint(20) -- 采购单ID erp_purch_bil.id 
	, uId bigint(20)
)
BEGIN

	DECLARE aCheck, aCost TINYINT;
	DECLARE aVendiId, aInUserId, aEmpId BIGINT(20);
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE msg VARCHAR(1000);
	DECLARE aPriceSumSell DECIMAL(20,4);

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

	SET msg = '采购单退回销售单时，';

	-- 获取用户信息
	CALL p_get_userInfo(uId, aEmpId, aName, aUserName);

	-- 获取采购单主表信息
	SELECT a.isCheck, a.isCost, a.inUserId, a.erp_vendi_bil_id 
	INTO aCheck, aCost, aInUserId, aVendiId
	FROM erp_purch_bil a WHERE a.id = aid;

	-- 根据采购单状态判断是否可以退回
	IF ISNULL(aCost) THEN
		SET msg = CONCAT(msg, '采购单（编号：', aid, '）不存在，不能退回到销售订单！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCost > 0 THEN
		SET msg = CONCAT(msg, '采购单（编号：', aid, '）已汇款确认，不能退回到销售订单！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aInUserId > 0 THEN
		SET msg = CONCAT(msg, '采购单（编号：', aid, '）已进仓完成，不能退回到销售订单！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > 0 THEN
		SET msg = CONCAT(msg, '采购单（编号：', aid, '）已提交待审或审核通过，不能退回到销售订单！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(aVendiId) THEN
		SET msg = CONCAT(msg, '该采购单是直接采购，不能退回到销售订单！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	
	START TRANSACTION;

	-- 删除采购流程状态表
	DELETE a FROM erp_purch_bilwfw a WHERE a.billId = aid;
	-- 删除采购明细表
	DELETE a FROM erp_purch_detail a WHERE a.erp_purch_bil_id = aid;
	-- 删除采购单
	DELETE a FROM erp_purch_bil a WHERE a.id = aid;

	-- 删除销售发货单
	DELETE a FROM erp_vendi_deliv a WHERE a.erp_vendi_bil_id = aVendiId;

	-- 修改账簿动态库存(补回销售订单审核通过时减去的动态库存)
	update erp_goodsbook a INNER JOIN erp_sales_detail b on a.goodsId = b.goodsId and b.erp_vendi_bil_id = aVendiId
	set a.dynamicQty = a.dynamicQty + b.qty, a.changeDate = CURDATE();
	if ROW_COUNT() = 0 THEN
		SET msg = CONCAT(msg, '未能成功修改账簿动态库存！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 修改日记账账簿销售动态库存(补回销售订单审核通过时减去的动态库存)
	update erp_goods_jz_day a INNER JOIN erp_sales_detail b on a.goodsId = b.goodsId and b.erp_vendi_bil_id = aVendiId
	set a.salesDynaimicQty = a.salesDynaimicQty + b.qty
	where a.datee = CURDATE();
	if ROW_COUNT() = 0 THEN
		SET msg = CONCAT(msg, '未能成功修改账簿动态库存！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 判断财务日报表当天是否存在
	IF NOT EXISTS (SELECT 1 FROM erf_daily_statement ds WHERE DATE(ds.createdDate) = DATE(NOW())) THEN
		CALL p_erf_daily_statement_new();
	END IF;
	-- 获取销售单销售总额
	SELECT v.priceSumSell INTO aPriceSumSell FROM erp_vendi_bil v WHERE v.id = aVendiId;
	-- 修改财务日报表(扣除销售订单审核通过时加上的应收金额)
	UPDATE erf_daily_statement ds SET ds.amountReceiveSum = ds.amountReceiveSum - aPriceSumSell
			, ds.amountReceivedBalance = ds.amountReceivedBalance - aPriceSumSell, ds.lastModifiedDate = NOW()
		WHERE DATE(ds.createdDate) = DATE(NOW());

	-- 退回销售订单状态为未提交
	UPDATE erp_vendi_bil vb SET vb.isCheck = -1, vb.isSubmit = -1, vb.lastModifiedId = uId WHERE vb.id = aVendiId;

	COMMIT;

END;;
DELIMITER ;