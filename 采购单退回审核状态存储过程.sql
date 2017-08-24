-- *****************************************************************************************************
-- 创建存储过程 p_purch_back_check, 采购单退回审核状态存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_purch_back_check`;
DELIMITER ;;
CREATE PROCEDURE `p_purch_back_check`
(
		aid bigint(20) -- 采购单ID erp_purch_bil.id 
	, uId bigint(20)
)
BEGIN

	DECLARE aCheck, aCost TINYINT;
	DECLARE aInUserId, aEmpId BIGINT(20);
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE msg VARCHAR(1000);
	DECLARE aPriceSumCome DECIMAL(20,4);

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

	SET msg = '采购单撤回审核状态时，';

	-- 获取用户信息
	CALL p_get_userInfo(uId, aEmpId, aName, aUserName);

	-- 获取采购单主表信息
	SELECT a.isCheck, a.isCost, a.inUserId
	INTO aCheck, aCost, aInUserId
	FROM erp_purch_bil a WHERE a.id = aid;

	-- 根据采购单状态判断是否可以退回
	IF ISNULL(aCheck) THEN
		SET msg = CONCAT(msg, '采购单（编号：', aid, '）不存在，不能撤回！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck < 1 THEN
		SET msg = CONCAT(msg, '采购单（编号：', aid, '）没有审核通过，不能撤回！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aInUserId > 0 THEN
		SET msg = CONCAT(msg, '采购单（编号：', aid, '）已进仓完成，不能退回到销售订单！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	
	START TRANSACTION;

	-- 删除生成的二维码
	-- 删除提货单
	-- 删除收款单

	-- 修改账簿动态库存
	update erp_goodsbook a INNER JOIN erp_purch_detail b on a.goodsId = b.goodsId and b.erp_purch_bil_id = aid
	set a.dynamicQty = a.dynamicQty - b.qty, a.changeDate = CURDATE();
	if ROW_COUNT() = 0 THEN
		SET msg = CONCAT(msg, '未能成功修改账簿动态库存！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 修改日记账账簿采购动态库存
	update erp_goods_jz_day a INNER JOIN erp_purch_detail b on a.goodsId = b.goodsId and b.erp_purch_bil_id = aid
	set a.purchDynaimicQty = a.purchDynaimicQty - b.qty
	where a.datee = CURDATE();
	if ROW_COUNT() = 0 THEN
		SET msg = CONCAT(msg, '未能成功修改账簿动态库存！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 判断财务日报表当天是否存在
	IF NOT EXISTS (SELECT 1 FROM erf_daily_statement ds WHERE DATE(ds.createdDate) = DATE(NOW())) THEN
		CALL p_erf_daily_statement_new();
	END IF;
	-- 更新日报表
	UPDATE erf_daily_statement ds SET ds.amountPaySum = ds.amountPaySum + new.priceSumCome
		, ds.amountPaidBalance = ds.amountPaidBalance + new.priceSumCome, ds.lastModifiedDate = NOW()
		WHERE ds.createdDate = CURDATE();
	if ROW_COUNT() <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据审核时，未能成功修改财务日报表！';
	end if;
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