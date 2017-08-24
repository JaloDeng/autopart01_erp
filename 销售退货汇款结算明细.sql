-- ----------------------------------------------------------------------------------------------------------------
-- 销售退货汇款结算明细
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS erf_customer_back_cash_detail;
CREATE TABLE `erf_customer_back_cash_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_vendi_back_id` bigint(20) NOT NULL COMMENT '销售退货单ID',
  `isCheck` tinyint(4) DEFAULT '0' COMMENT '审核状态 -1:未提交或审核退回 0:提交待审 1:已审核',
  `customId` bigint(20) DEFAULT NULL COMMENT '客服号',
  `customerId` bigint(20) DEFAULT NULL COMMENT '供应商ID',
  `creatorId` bigint(20) DEFAULT NULL COMMENT '初建用户ID',
  `lastModifiedId` bigint(20) NOT NULL COMMENT '更新用户ID',
  `handlerId` bigint(20) DEFAULT NULL COMMENT '经手用户ID，出纳',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核人',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `costTime` datetime DEFAULT NULL COMMENT '汇款时间',
  `settleTime` datetime DEFAULT NULL COMMENT '结算时间',
  `checkTime` datetime DEFAULT NULL COMMENT '审核时间',
  `priceSumSell` decimal(20,4) DEFAULT 0 COMMENT '总额，售价+运费',
  `empName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建员工姓名',
  `lastModifiedEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '更新员工姓名',
  `handlerEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '经手员工姓名，出纳',
  `checkEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '审核人',
  `customerName` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '收款方',
  `payAccount` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '付款方账号',
  `receiveAccount` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '收款方账号',
  `customerReceiving` decimal(20,4) DEFAULT 0 COMMENT '退回客户金额',
  `amountPaying` decimal(20,4) DEFAULT 0 COMMENT '实汇金额(审核以后才能变更）',
  `amountPaid` decimal(20,4) DEFAULT 0 COMMENT '已汇金额',
  `balance` decimal(20,4) DEFAULT NULL COMMENT '余额',
  `code` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '汇款单号，格式：销售提货单号-001',
  `serialNum` varchar(50) DEFAULT NULL COMMENT '流水号',
  `paymentType` varchar(40) DEFAULT NULL COMMENT '支付方式，汇款、第三方平台',
  `pasteimg` longtext DEFAULT NULL COMMENT '支付凭证，图片的地址',
  `memo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `erf_supplier_cash_erp_purch_bil_id_idx` (`erp_purch_bil_id`),
  KEY `erf_supplier_cash_code_idx` (`code`),
  KEY `erf_supplier_cash_costTime_idx` (`costTime`,`payAccount`),
  KEY `erf_supplier_cash_receiveAccount_idx` (`receiveAccount`),
  KEY `erf_supplier_cash_balance_idx` (`balance`),
  KEY `erf_supplier_cash_paymentType_idx` (`paymentType`),
  CONSTRAINT `fk_erf_supplier_cash_erp_purch_bil_id` FOREIGN KEY (`erp_purch_bil_id`) 
		REFERENCES `erp_purch_bil` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='财务汇款现金结算明细'
;

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erf_supplier_cash_detail_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER tr_erf_supplier_cash_detail_BEFORE_INSERT BEFORE INSERT ON erf_supplier_cash_detail FOR EACH ROW 
BEGIN

	DECLARE aCheck, aCost TINYINT;
	DECLARE aEmpId, aSupplierId BIGINT(20);
	DECLARE aPriceSumCome, aAmountPaid DECIMAL(20,4);
	DECLARE aEmpName, aUserName, aPurchCode VARCHAR(100);

	-- 获取用户信息
	CALL p_get_userInfo(new.lastModifiedId, aEmpId, aEmpName, aUserName);

	-- 获取采购订单信息
	SELECT p.isCheck, p.isCost, p.priceComeShip, p.purchCode, p.supplierId
	INTO aCheck, aCost, aPriceSumCome, aPurchCode, aSupplierId
	FROM erp_purch_bil p WHERE p.id = new.erp_purch_bil_id;

	-- 获取最新已汇金额
	SELECT IFNULL(MAX(scd.amountPaid),0) INTO aAmountPaid
	FROM erf_supplier_cash_detail scd WHERE scd.erp_purch_bil_id = new.erp_purch_bil_id;

	-- 根据采购订单状态是否可以确认汇款
	IF aCheck <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购订单没有审核通过，不能进行汇款！';
	ELSEIF aCost <> 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购订单汇款完毕，不能进行汇款！';
-- 	ELSEIF new.amountPaying <= 0 THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请输入有效金额！';
-- 	ELSEIF aAmountPaid + new.amountPaying > aPriceSumCome THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '实汇金额总共已超出采购订单金额，不能进行汇款！';
	ELSEIF ISNULL(aSupplierId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购订单没有指定有效供应商，不能进行汇款！';
	END IF;

	-- 设置相关字段
	SET new.creatorId = new.lastModifiedId, new.supplierId = aSupplierId
		, new.createdDate = NOW(), new.priceSumCome = aPriceSumCome, new.empName = aEmpName
		, new.lastModifiedEmpName = aEmpName, new.amountPaid = aAmountPaid
		, new.balance = aPriceSumCome - new.amountPaid;
	-- 设置汇款单号
	SET new.code = CONCAT(aPurchCode, '-'
		, LPAD(
				IFNULL((SELECT MAX(RIGHT(scd.code,3)) FROM erf_supplier_cash_detail scd WHERE scd.erp_purch_bil_id = new.erp_purch_bil_id),0)+1
			, 3, 0)
		);

	IF NOT EXISTS (SELECT 1 FROM erf_daily_statement ds WHERE ds.createdDate = CURDATE()) THEN
		CALL p_erf_daily_statement_new();
	END IF;
-- 	IF EXISTS (SELECT 1 FROM erf_daily_statement ds WHERE ds.createdDate = CURDATE() 
-- 		AND ds.amountPaidBalance - new.amountPaying < 0) THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '出现余额少于0情况！';
-- 	END IF;
-- 	-- 更新日报表
-- 	UPDATE erf_daily_statement ds SET ds.amountPaid = ds.amountPaid + new.amountPaying
-- 			, ds.amountPaidBalance = ds.amountPaidBalance - new.amountPaying, ds.lastModifiedDate = NOW()
-- 		WHERE ds.createdDate = CURDATE();
-- 
-- 	-- 判断金额是否全部收齐，是则设置采购订单汇款确认状态
-- 	IF new.balance = 0 THEN
-- 		UPDATE erp_purch_bil p SET p.isCost = 1, p.lastModifiedId = new.lastModifiedId WHERE p.id = new.erp_purch_bil_id;
-- 	ELSEIF new.balance < 0 THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '出现余额少于0情况，不能进行汇款！';
-- 	END IF;
-- 写入流程状态
	insert into erp_purch_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.erp_purch_bil_id, 'cost', new.lastModifiedId, aEmpId, aEmpName, aUserName
		, CONCAT('采购（', aEmpName, '）提醒汇款。');
END;;
DELIMITER ;

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erf_supplier_cash_detail_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER tr_erf_supplier_cash_detail_BEFORE_UPDATE BEFORE UPDATE ON erf_supplier_cash_detail FOR EACH ROW 
BEGIN

	DECLARE aCheck, aCost TINYINT;
	DECLARE aEmpId BIGINT(20);
	DECLARE aEmpName, aUserName VARCHAR(100);
	DECLARE aPriceSumCome, aAmountPaid DECIMAL(20,4);

	IF old.settleTime > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该汇款单已审核并确认汇款，不能修改！';
	END IF;

	-- 获取用户信息
	CALL p_get_userInfo(new.lastModifiedId, aEmpId, aEmpName, aUserName);

	SET new.lastModifiedEmpName = aEmpName;

	-- 获取采购订单信息
	SELECT p.isCheck, p.isCost, p.priceComeShip
	INTO aCheck, aCost, aPriceSumCome
	FROM erp_purch_bil p WHERE p.id = new.erp_purch_bil_id;

	-- 获取最新已汇金额
	SELECT IFNULL(MAX(scd.amountPaid),0) INTO aAmountPaid
	FROM erf_supplier_cash_detail scd WHERE scd.erp_purch_bil_id = new.erp_purch_bil_id;

	IF new.isCheck = 1 AND old.isCheck = 0 THEN -- 通过审核
		IF new.erp_purch_bil_id <> old.erp_purch_bil_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核时，已指定采购订单，不能修改采购订单！';
		ELSEIF aCost <> 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购订单已全部汇款完毕，不能审核通过！';
		ELSEIF new.amountPaying <> old.amountPaying THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核时，不能更改汇款金额！';
		END IF;
		-- 写入相关值
		SET new.checkTime = NOW(), new.checkEmpName = aEmpName;
		-- 记录操作
		insert into erp_purch_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.erp_purch_bil_id, 'costCheck', new.lastModifiedId, aEmpId, aEmpName, aUserName
			, CONCAT('员工（', IFNULL(aEmpName,''), '）审核通过汇款单（', new.`code`, '）。');
	ELSEIF new.isCheck = 0 AND old.isCheck = -1 THEN -- 审核不通过
		IF new.erp_purch_bil_id <> old.erp_purch_bil_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核时，已指定采购订单，不能修改采购订单！';
		ELSEIF new.amountPaying <> old.amountPaying THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核时，不能更改汇款金额！';
		END IF;
		-- 记录操作
		insert into erp_purch_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.erp_purch_bil_id, 'costCheckBack', new.lastModifiedId, aEmpId, aEmpName, aUserName
			, CONCAT('员工（', IFNULL(aEmpName,''), '）审核不通过汇款单（', new.`code`, '）。');
	ELSEIF old.amountPaying = 0 AND new.amountPaying > 0 THEN -- 出纳确认汇款
		-- 根据状态判断是否能确认
		IF old.isCheck <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '汇款单没有审核通过，不能确认汇款！';
		ELSEIF new.erp_purch_bil_id <> old.erp_purch_bil_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '已指定采购订单，不能修改采购订单！';
		ELSEIF aCheck <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购订单没有审核通过，不能进行汇款确认！';
		ELSEIF aCost <> 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购订单已全部汇款完毕，不能进行汇款确认！';
		ELSEIF new.amountPaying <= 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请输入有效金额！';
		ELSEIF old.amountPaying > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能修改实际汇款金额！';
		ELSEIF old.supplierReceiving <> new.supplierReceiving THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能修改供应商要求的汇款金额！';
		ELSEIF old.supplierReceiving <> new.amountPaying THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '汇款金额与供应商要求的汇款金额不同，不能进行汇款确认！';
		ELSEIF aAmountPaid + new.amountPaying - old.amountPaying > aPriceSumCome THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '实际汇款金额总共已超出采购订单金额，不能进行收款确认！';
		ELSEIF new.lastModifiedId <> new.handlerId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '汇款确认时，最新操作员工必须与经手人相同！';
		END IF;

		-- 设置相关字段
		SET new.settleTime = NOW(), new.handlerEmpName = aEmpName
			, new.amountPaid = aAmountPaid + new.amountPaying - old.amountPaying
			, new.balance = aPriceSumCome - new.amountPaid;

		-- 更新日报表
		UPDATE erf_daily_statement ds SET ds.amountPaid = ds.amountPaid + new.amountPaying - old.amountPaying
				, ds.amountPaidBalance = ds.amountPaidBalance - new.amountPaying + old.amountPaying
				, ds.lastModifiedDate = NOW()
			WHERE ds.createdDate = CURDATE();

		-- 判断金额是否全部收齐，是则设置采购订单汇款确认状态
		IF new.balance = 0 THEN
			UPDATE erp_purch_bil p SET p.isCost = 1, p.lastModifiedId = new.lastModifiedId WHERE p.id = new.erp_purch_bil_id;
		ELSEIF new.balance < 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '出现余额少于0情况，不能进行汇款！';
		END IF;

		-- 写入流程状态
		insert into erp_purch_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.erp_purch_bil_id, 'cost', new.lastModifiedId, aEmpId, aEmpName, aUserName
			, CONCAT('员工（', new.handlerEmpName, '）确认汇款（', new.`code`, '），金额：', new.amountPaying, '。');
	END IF;

END;;
DELIMITER ;