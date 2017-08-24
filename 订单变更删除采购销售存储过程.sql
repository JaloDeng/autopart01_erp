-- *****************************************************************************************************
-- 创建存储过程 p_goods_change_shelfattr, 删除采购单、销售订单，取消询价单生成状态
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_purch_vendi_back`;
DELIMITER ;;
CREATE PROCEDURE `p_purch_vendi_back`(
	aid bigint(20) -- 采购单ID erp_purch_bil.id 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
)
BEGIN

	DECLARE aCheck, aCost TINYINT;
	DECLARE aInquiryId, aVendiId, aInUserId, aEmpId BIGINT(20);
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE msg VARCHAR(1000);
	DECLARE aPriceSumSell DECIMAL(20,4);

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

	SET msg = '采购单退回询价单时，';

	-- 判断用户是否合理
	IF NOT EXISTS(SELECT 1 FROM autopart01_security.sec$user a WHERE a.ID = uId) THEN
		SET msg = CONCAT(msg, '请指定有效用户！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSE
		CALL p_get_userInfo(uId, aEmpId, aName, aUserName);
	END IF;

	-- 获取采购单主表信息
	SELECT a.isCheck, a.isCost, a.inUserId, a.erp_inquiry_bil_id, a.erp_vendi_bil_id 
	INTO aCheck, aCost, aInUserId, aInquiryId, aVendiId
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
	ELSEIF ISNULL(aVendiId) OR ISNULL(aInquiryId) THEN
		SET msg = CONCAT(msg, '该采购单是直接采购，不能退回到销售订单！！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;
	
	START TRANSACTION;

	-- 删除采购流程状态表
	DELETE a FROM erp_purch_bilwfw a, erp_purch_bil b WHERE a.billId = b.id AND b.erp_vendi_bil_id = aVendiId;
	-- 删除采购明细表
	DELETE FROM erp_purch_detail WHERE erp_vendi_bil_id = aVendiId;
	-- 删除采购单
	DELETE FROM erp_purch_bil WHERE erp_vendi_bil_id = aVendiId;

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

	-- 删除销售发货单
	DELETE FROM erp_vendi_deliv WHERE erp_vendi_bil_id = aVendiId;
	-- 删除销售流程状态表
	DELETE FROM erp_vendi_bilwfw WHERE billId = aVendiId;
	-- 删除销售明细表
	DELETE FROM erp_sales_detail WHERE erp_vendi_bil_id = aVendiId;
	-- 删除销售单
	DELETE FROM erp_vendi_bil WHERE id = aVendiId;

	-- 更改询价单状态（跟单处理）
	UPDATE erp_inquiry_bil a SET a.ischeck = 0, a.isSubmit = 1 WHERE a.id = aInquiryId;
	if ROW_COUNT() = 0 THEN
		SET msg = CONCAT(msg, '未能成功修改询价单状态！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 更新询价报价明细的销售订单字段
	UPDATE erp_vendi_detail a SET a.erp_vendi_bil_id = NULL, a.lastModifiedId = uId WHERE a.erp_inquiry_bil_id = aInquiryId;
	if ROW_COUNT() = 0 THEN
		SET msg = CONCAT(msg, '未能成功修改询价报价明细状态！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 记录操作
	insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
	select aInquiryId, 'purchBack', uId, aEmpId, aName, aUserName, '采购单退回';

	COMMIT;

END;;
DELIMITER ;