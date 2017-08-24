-- *****************************************************************************************************
-- 创建存储过程 p_purch_cost, 采购汇款存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS `p_purch_cost`;
DELIMITER ;;
CREATE PROCEDURE `p_purch_cost`(
		pdId BIGINT(20) -- 采购明细ID
	, uId BIGINT(20) -- 用户ID
)
BEGIN

	DECLARE pCheck, pCost TINYINT;
	DECLARE aEmpId, pId, pdGoodsId, pdSupplier BIGINT(20);
	DECLARE pdCostTime datetime;
	DECLARE aEmpName, aUserName, purchCode, inquiryCode VARCHAR(100);
	DECLARE msg VARCHAR(1000);

	SET msg = CONCAT('采购明细（编号：', pdId, '）汇款确认时，');

	-- 获取用户信息
	IF NOT EXISTS(SELECT 1 FROM autopart01_security.sec$user a WHERE a.ID = uId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效用户操作采购汇款！';
	ELSE
		CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);
	END IF;

	-- 获取采购单主表、明细信息
	SELECT p.id, p.isCheck, p.isCost, pd.costTime, pd.goodsId, pd.supplierId, p.`code`, p.inquiryCode
	INTO pId, pCheck, pCost, pdCostTime, pdGoodsId, pdSupplier, purchCode, inquiryCode
	FROM erp_purch_detail pd INNER JOIN erp_purch_bil p ON p.id = pd.erp_purch_bil_id
	WHERE pd.id = pdId;

	-- 根据单据状态判断能否汇款
	IF ISNULL(pId) THEN
		SET msg = CONCAT(msg, '该采购单不存在，不能确认汇款！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(pdGoodsId) THEN
		SET msg = CONCAT(msg, '该配件不存在，不能确认汇款！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF pCheck <> 1 THEN
		SET msg = CONCAT(msg, '该采购单没有审核通过，不能确认汇款！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF pCost = 1 THEN
		SET msg = CONCAT(msg, '该采购单已汇款完毕，不能重复确认汇款！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF pdCostTime > 0 THEN
		SET msg = CONCAT(msg, '配件（编号：', pdGoodsId, '）该采购明细已汇款完毕，不能重复确认汇款！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 更新采购明细汇款时间
	UPDATE erp_purch_detail pd SET pd.costTime = NOW(), pd.lastModifiedId = uId
	WHERE pd.id = pdId;
	if ROW_COUNT() <> 1 THEN
		set msg = concat(msg, '未能修改采购明细汇款时间！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	-- 记录操作
-- 	insert into erp_purch_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
-- 		select pId, 'cost', uId, aEmpId, aEmpName, aUserName
-- 			, CONCAT('采购明细（编号：', pdId, '，配件编号：', pdGoodsId, '）汇款完毕！');

	-- 如果同一采购单同一供应商的明细全部汇款确认
	IF NOT EXISTS(SELECT 1 FROM erp_purch_detail pd WHERE pd.erp_purch_bil_id = pId 
		AND pd.supplierId = pdSupplier AND ISNULL(pd.costTime) LIMIT 1) THEN
			-- 生成采购提货单
			INSERT INTO erp_purch_pick(erp_purch_bil_id, supplierId, userId, empId, userName, empName
				, opTime, lastModifiedId, lastModifiedDate, purchCode, inquiryCode)
			SELECT pId, pdSupplier, uId, aEmpId, aUserName, aEmpName
				, NOW(), uId, NOW(), purchCode, inquiryCode;
			if ROW_COUNT() <> 1 THEN
				set msg = concat(msg, '无法生成采购提货单！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;
			-- 记录操作
			insert into erp_purch_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
				select pId, 'createPick', uId, aEmpId, aEmpName, aUserName
				, CONCAT('生成采购提货单（供应商编号：', pdGoodsId, '）！');
	END IF;

	-- 判断采购单明细是否全部汇款
	IF NOT EXISTS(SELECT 1 FROM erp_purch_detail pd WHERE pd.erp_purch_bil_id = pId 
		AND ISNULL(pd.costTime) LIMIT 1) THEN
			-- 修改主表汇款确认标志位
			UPDATE erp_purch_bil a SET a.isCost = 1, a.costUserId = uId, a.lastModifiedId = uId
			WHERE a.id = pId;
			if ROW_COUNT() <> 1 THEN
				set msg = concat(msg, '无法修改采购单（编号：', pId, '）汇款完毕信息！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			end if;
			-- 记录操作
-- 			insert into erp_purch_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
-- 				select pId, 'cost', uId, aEmpId, aEmpName, aUserName
-- 				, CONCAT('采购单（编号：', pId, '）全部配件汇款完毕！');
	END IF;

END;;
DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_call_purch_cost, 采购汇款存储过程
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_call_purch_cost;
DELIMITER ;;
CREATE PROCEDURE `p_call_purch_cost`(
	aids VARCHAR(65535) CHARSET latin1 -- 采购明细ID erp_purch_detail.id(集合，用xml格式) 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, qty INT(11) -- 采购明细个数
)
BEGIN

	DECLARE i INT DEFAULT 1;
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;
	
	START TRANSACTION;
	
	WHILE i < qty+1 DO
		CALL p_purch_cost(ExtractValue(aids, '//a[$i]'), uId);
		SET i = i+1;
	END WHILE;

	COMMIT;  

END;;
DELIMITER ;