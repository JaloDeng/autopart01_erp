-- ----------------------------------------------------------------------------------------------------------------
-- 财务收款现金结算明细
-- ----------------------------------------------------------------------------------------------------------------
DROP TABLE if EXISTS erf_customer_cash_detail;
CREATE TABLE `erf_customer_cash_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_vendi_bil_id` bigint(20) NOT NULL COMMENT '销售订单ID',
  `isCheck` tinyint(4) DEFAULT '-1' COMMENT '审核状态 -1:未提交或审核退回 0:提交待审（结算时自动将值设为0） 1:已审核',
  `isSettle` tinyint(4) DEFAULT '0' COMMENT '结算状态 0:未结算 1:已结算',
  `customId` bigint(20) DEFAULT NULL COMMENT '客服号',
  `customerId` bigint(20) DEFAULT NULL COMMENT '客户ID',
  `creatorId` bigint(20) DEFAULT NULL COMMENT '初建用户ID',
  `lastModifiedId` bigint(20) NOT NULL COMMENT '更新用户ID',
  `handlerId` bigint(20) DEFAULT NULL COMMENT '经手用户ID，出纳',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核人ID',
  `settleUserId` bigint(20) DEFAULT NULL COMMENT '结算操作人ID',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `costTime` datetime DEFAULT NULL COMMENT '收款时间',
  `costShipTime` datetime DEFAULT NULL COMMENT '运费收款时间',
  `handlerTime` datetime DEFAULT NULL COMMENT '审核时间',
  `checkTime` datetime DEFAULT NULL COMMENT '审核时间',
  `settleTime` datetime DEFAULT NULL COMMENT '结算时间',
  `priceSumSell` decimal(20,4) DEFAULT 0 COMMENT '销售总价',
  `priceSumShip` decimal(20,4) DEFAULT 0 COMMENT '单子运费',
  `priceDiscount` decimal(20,4) DEFAULT 0 COMMENT '优惠费用',
  `empName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建员工姓名',
  `lastModifiedEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '更新员工姓名',
  `handlerEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '经手员工姓名，出纳',
  `checkEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '审核人',
  `settleEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '结算操作人',
  `customerName` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '付款方',
  `payAccount` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '付款方账号',
  `receiveAccount` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '收款方账号',
  `deposit` decimal(20,4) DEFAULT 0 COMMENT '定金',
  `customerPaying` decimal(20,4) DEFAULT 0 COMMENT '客人付款金额，客人告知客服当次付款金额',
  `amountReceiving` decimal(20,4) DEFAULT 0 COMMENT '实收金额',
  `amountShipReceiving` decimal(20,4) DEFAULT 0 COMMENT '实收运费金额',
  `amountReceived` decimal(20,4) DEFAULT 0 COMMENT '已收金额',
  `amountShipReceived` decimal(20,4) DEFAULT 0 COMMENT '已收运费金额',
  `balance` decimal(20,4) DEFAULT NULL COMMENT '余额',
  `shipBalance` decimal(20,4) DEFAULT NULL COMMENT '应收运费余额',
  `code` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '收款单号，格式：询价单号-001',
  `serialNum` varchar(50) DEFAULT NULL COMMENT '流水号',
  `paymentType` varchar(40) DEFAULT NULL COMMENT '支付方式，汇款、第三方平台',
  `pasteimg` longtext COLLATE utf8mb4_unicode_ci COMMENT '支付凭证，图片的地址',
  `memo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `erf_customer_cash_erp_vendi_bil_id_idx` (`erp_vendi_bil_id`),
  KEY `erf_customer_cash_code_idx` (`code`),
  KEY `erf_customer_cash_costTime_idx` (`costTime`,`payAccount`),
  KEY `erf_customer_cash_receiveAccount_idx` (`receiveAccount`),
  KEY `erf_customer_cash_balance_idx` (`balance`),
  KEY `erf_customer_cash_paymentType_idx` (`paymentType`),
  CONSTRAINT `fk_erf_customer_cash_erp_vendi_bil_id` FOREIGN KEY (`erp_vendi_bil_id`) 
		REFERENCES `erp_vendi_bil` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='财务收款现金结算明细'
;

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erf_customer_cash_detail_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER tr_erf_customer_cash_detail_BEFORE_INSERT BEFORE INSERT ON erf_customer_cash_detail FOR EACH ROW 
BEGIN

	DECLARE aCheck, aCost TINYINT;
	DECLARE aEmpId, aCreatorId, aCustomerId BIGINT(20);
	DECLARE aPriceSumSell, aPriceSumShip, aPriceDiscount, aAmountReceived, aAmountShipReceived, aBalance, aShipBalance DECIMAL(20,4);
	DECLARE aEmpName, aUserName, aInquiryCode VARCHAR(100);

	-- 获取用户信息
	CALL p_get_userInfo(new.lastModifiedId, aEmpId, aEmpName, aUserName);

	-- 获取销售订单信息
	SELECT v.isCheck, v.isCost, v.creatorId, v.customerId, IFNULL(v.priceSumSell,0), IFNULL(v.priceSumShip,0), IFNULL(v.priceDiscount,0), v.inquiryCode
	INTO aCheck, aCost, aCreatorId, aCustomerId, aPriceSumSell, aPriceSumShip, aPriceDiscount, aInquiryCode
	FROM erp_vendi_bil v WHERE v.id = new.erp_vendi_bil_id;

	-- 获取最新已收金额、运费金额
	SELECT IFNULL(MAX(ccd.amountReceived),0), IFNULL(MAX(ccd.amountShipReceived),0) 
	INTO aAmountReceived, aAmountShipReceived
	FROM erf_customer_cash_detail ccd WHERE ccd.erp_vendi_bil_id = new.erp_vendi_bil_id;

	-- 根据销售订单状态是否可以确认收款
	IF aCheck <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售订单没有审核通过，不能进行收款确认！';
	ELSEIF aCost <> 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售订单已收齐余额，不能进行收款确认！';
	ELSEIF ISNULL(aCustomerId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售单没有指定有效客户，不能进行收款确认！';
	END IF;

	-- 设置相关字段
	SET new.customId = aCreatorId, new.customerId = aCustomerId
		, new.creatorId = new.lastModifiedId, new.createdDate = NOW()
		, new.empName = aEmpName, new.lastModifiedEmpName = aEmpName
		, new.priceSumSell = aPriceSumSell, new.priceSumShip = aPriceSumShip
		, new.amountReceived = aAmountReceived, new.amountShipReceived = aAmountShipReceived, new.priceDiscount = aPriceDiscount
		, new.balance = aPriceSumSell - aPriceDiscount - IFNULL(new.amountReceived,0), new.shipBalance = aPriceSumShip - IFNULL(new.amountShipReceived,0);

	-- 设置收款单号
	SET new.code = CONCAT(aInquiryCode, '-'
		, LPAD(
				IFNULL((SELECT MAX(RIGHT(ccd.code,3)) FROM erf_customer_cash_detail ccd WHERE ccd.erp_vendi_bil_id = new.erp_vendi_bil_id),0)+1
			, 3, 0)
		);

	-- 获取同一销售订单最新一条余额
	SELECT ccd.balance, ccd.shipBalance INTO aBalance, aShipBalance
	FROM erf_customer_cash_detail ccd WHERE ccd.erp_vendi_bil_id = new.erp_vendi_bil_id 
		AND ccd.createdDate = (SELECT MAX(ccd1.createdDate) FROM erf_customer_cash_detail ccd1 WHERE ccd1.erp_vendi_bil_id = new.erp_vendi_bil_id);
	-- 判断余额是否少于0
	IF aBalance + aShipBalance < new.customerPaying THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '输入金额多于该总共未收余额！';
	END IF;

	-- 记录操作
	INSERT INTO erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		SELECT new.erp_vendi_bil_id, 'cost', new.lastModifiedId, aEmpId, aEmpName, aUserName
			, CONCAT('客服（', aEmpName, '）提醒收款，客人付款金额：', new.customerPaying, '。');
END;;
DELIMITER ;

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erf_customer_cash_detail_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER tr_erf_customer_cash_detail_BEFORE_UPDATE BEFORE UPDATE ON erf_customer_cash_detail FOR EACH ROW 
BEGIN

	DECLARE aCheck, aCost TINYINT;
	DECLARE aEmpId BIGINT(20);
	DECLARE aPriceSumSell, aPriceSumShip, aAmountReceived, aAmountShipReceived, aAmountReceiving, aAmountShipReceiving DECIMAL(20,4);
	DECLARE aEmpName, aUserName VARCHAR(100);

	-- 获取用户信息
	CALL p_get_userInfo(new.lastModifiedId, aEmpId, aEmpName, aUserName);
	-- 修改最新操作员工
	SET new.lastModifiedEmpName = aEmpName;

	-- 获取销售订单信息
	SELECT v.isCheck, v.isCost, v.priceSellShip, v.priceSumShip
	INTO aCheck, aCost, aPriceSumSell, aPriceSumShip
	FROM erp_vendi_bil v WHERE v.id = new.erp_vendi_bil_id;
	-- 获取最新已收金额
	SELECT IFNULL(MAX(ccd.amountReceived),0), IFNULL(MAX(ccd.amountShipReceived),0) INTO aAmountReceived, aAmountShipReceived
	FROM erf_customer_cash_detail ccd WHERE ccd.erp_vendi_bil_id = new.erp_vendi_bil_id;

	IF new.isCheck = 1 AND old.isCheck = 0 THEN -- 通过审核
		-- 根据收款单状态判断是否可以审核
		IF ISNULL(new.settleTime) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '改收款单没有结算，不能审核！';
		ELSEIF new.handlerEmpName = aEmpName THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '收款单不能由出纳自己审核！';
		END IF;
		-- 写入相关值
		SET new.checkTime = NOW(), new.checkEmpName = aEmpName;
		-- 记录操作
		INSERT INTO erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		SELECT new.erp_vendi_bil_id, 'costCheck', new.lastModifiedId, aEmpId, aEmpName, aUserName
			, CONCAT('员工（', IFNULL(aEmpName,''), '）审核收款。');
	ELSEIF new.isCheck = 0 AND old.isCheck = 1 THEN -- 撤回审核
		-- 写入相关值
		SET new.checkTime = NULL, new.checkEmpName = NULL;
		-- 记录操作
		INSERT INTO erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		SELECT new.erp_vendi_bil_id, 'costCheckBack', new.lastModifiedId, aEmpId, aEmpName, aUserName
			, CONCAT('员工（', IFNULL(aEmpName,''), '）撤回审核。');
	ELSEIF old.isSettle = 0 AND new.isSettle = 1 THEN -- 结算
		-- 根据状态判断是否能结算
		IF new.erp_vendi_bil_id <> old.erp_vendi_bil_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '已指定销售订单，不能修改销售订单！';
		ELSEIF aCheck <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售订单没有审核通过，不能进行收款确认！';
		ELSEIF aCost <> 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售订单已收齐余额，不能进行收款确认！';
		ELSEIF new.amountReceiving <= 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请输入有效金额！';
		ELSEIF old.amountReceiving <> new.amountReceiving THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能修改实际收款金额！';
		ELSEIF aAmountReceived + new.amountReceiving - old.amountReceiving > aPriceSumSell THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '实收金额总共已超出销售订单金额，不能进行收款确认！';
		ELSEIF new.lastModifiedId <> new.settleUserId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '收款确认时，最新操作员工必须与结算操作人相同！';
		END IF;

		-- 更新相关字段
		SET new.settleTime = NOW(), new.settleEmpName = aEmpName, new.isCheck = 0;

		-- 判断财务日报表当天是否存在
		IF NOT EXISTS (SELECT 1 FROM erf_daily_statement ds WHERE ds.createdDate = CURDATE()) THEN
			CALL p_erf_daily_statement_new();
		END IF;

		-- 更新日报表
		UPDATE erf_daily_statement ds SET ds.amountReceived = ds.amountReceived + new.amountReceiving
			, ds.amountReceivedBalance = ds.amountReceivedBalance - new.amountReceiving
			, ds.lastModifiedDate = NOW()
		WHERE ds.createdDate = CURDATE();

		-- 判断金额是否全部收齐，是则设置销售订单付款状态
		SELECT SUM(ccd.amountReceiving), SUM(ccd.amountShipReceiving)
		INTO aAmountReceiving, aAmountShipReceiving
		FROM erf_customer_cash_detail ccd WHERE ccd.erp_vendi_bil_id = new.erp_vendi_bil_id AND ccd.isSettle;
		IF aAmountReceiving + aAmountShipReceiving = aPriceSumSell + aPriceSumShip - new.priceDiscount THEN
			UPDATE erp_vendi_bil v SET v.isCost = 1, v.lastModifiedId = new.lastModifiedId WHERE v.id = new.erp_vendi_bil_id;
		END IF;

		-- 记录操作
		INSERT INTO erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		SELECT new.erp_vendi_bil_id, 'settle', new.lastModifiedId, aEmpId, aEmpName, aUserName
			, CONCAT('员工（', aEmpName, '）结算，金额：', new.amountReceiving, '。');
	ELSEIF old.isSettle = 1 AND new.isSettle = 0 THEN -- 撤回结算
		-- 根据状态判断是否能撤回结算
		IF new.erp_vendi_bil_id <> old.erp_vendi_bil_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '已指定销售订单，不能修改销售订单！';
		ELSEIF aCost <> 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售订单已收齐余额，不能撤回！';
		ELSEIF old.amountReceiving <> new.amountReceiving THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能修改实际收款金额！';
		END IF;

		-- 更新相关字段
		SET new.settleTime = NULL, new.settleEmpName = aEmpName;

		-- 判断财务日报表当天是否存在
		IF NOT EXISTS (SELECT 1 FROM erf_daily_statement ds WHERE ds.createdDate = CURDATE()) THEN
			CALL p_erf_daily_statement_new();
		END IF;

		-- 更新日报表(减去结算时增加的金额)
		UPDATE erf_daily_statement ds SET ds.amountReceived = ds.amountReceived - new.amountReceiving
			, ds.amountReceivedBalance = ds.amountReceivedBalance + new.amountReceiving
			, ds.lastModifiedDate = NOW()
		WHERE ds.createdDate = CURDATE();

		-- 记录操作
		INSERT INTO erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		SELECT new.erp_vendi_bil_id, 'settle', new.lastModifiedId, aEmpId, aEmpName, aUserName
			, CONCAT('员工（', new.lastModifiedEmpName, '）撤回结算，金额：', new.amountReceiving, '。');
	ELSEIF old.amountReceiving <> new.amountReceiving OR old.amountShipReceiving <> new.amountShipReceiving THEN -- 出纳填写单子或运费金额
		-- 根据状态判断是否能结算
		IF old.isCheck > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '收款单已进入审核流程，不能填写！';
		ELSEIF old.isSettle > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '收款单已结算，不能填写金额！';
		ELSEIF new.erp_vendi_bil_id <> old.erp_vendi_bil_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '已指定销售订单，不能修改销售订单！';
		ELSEIF aCheck <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售订单没有审核通过，不能填写金额！';
		ELSEIF aCost <> 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该销售订单已收齐余额，不能填写金额！';
		ELSEIF new.priceDiscount <> old.priceDiscount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能修改优惠金额！';
		ELSEIF new.amountReceiving <= 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请输入有效金额！';
		ELSEIF aAmountReceived + new.amountReceiving - old.amountReceiving > aPriceSumSell - new.priceDiscount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '实收金额总共已超出销售订单金额，不能填写！';
		ELSEIF new.lastModifiedId <> new.handlerId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '填写金额时，最新操作员工必须与经手人相同！';
		END IF;

		IF old.amountReceiving <> new.amountReceiving THEN -- 单子金额
			-- 更新相关字段
			SET new.amountReceived = aAmountReceived + new.amountReceiving - old.amountReceiving
				, new.balance = aPriceSumSell - new.priceDiscount - new.amountReceived
				;
			-- 记录操作
			INSERT INTO erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
			SELECT new.erp_vendi_bil_id, 'cost', new.lastModifiedId, aEmpId, aEmpName, aUserName
				, CONCAT('员工（', new.lastModifiedEmpName, '）修改金额：', new.amountReceiving, '。');
		END IF;
		IF old.amountShipReceiving <> new.amountShipReceiving THEN -- 运费金额
			-- 更新相关字段
			SET new.amountShipReceived = aAmountShipReceived + new.amountShipReceiving - old.amountShipReceiving
				, new.shipBalance = aPriceSumShip - new.amountShipReceived
				;
			-- 记录操作
			INSERT INTO erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
			SELECT new.erp_vendi_bil_id, 'cost', new.lastModifiedId, aEmpId, aEmpName, aUserName
				, CONCAT('员工（', new.lastModifiedEmpName, '）修改运费金额：', new.amountReceiving, '。');
		END IF;

		-- 判断金额是否全部收齐，是则设置销售订单付款状态
		IF new.balance < 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '出现余额少于0情况，不能进行修改收款单明细！';
		ELSEIF new.shipBalance < 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '出现运费余额少于0情况，不能进行修改收款单明细！';
		END IF;

	END IF;

END;;
DELIMITER ;

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erf_customer_cash_detail_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER tr_erf_customer_cash_detail_BEFORE_DELETE BEFORE DELETE ON erf_customer_cash_detail FOR EACH ROW 
BEGIN

	DECLARE msg varchar(1000);

	SET msg = CONCAT('收款单（', old.`code`, '）');

	IF old.isCheck > -1 THEN
		SET msg = CONCAT(msg, '进入审核流程，不能删除');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF old.isSettle > 0 THEN
		SET msg = CONCAT(msg, '已经结算，不能删除');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

END;;
DELIMITER ;