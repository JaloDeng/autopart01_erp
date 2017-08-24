-- ------------------------------------------------------------------------------------------------------------------------------------------
-- 出纳日报表
-- ------------------------------------------------------------------------------------------------------------------------------------------
-- DROP TABLE IF EXISTS `erf_daily_statement`;
-- CREATE TABLE `erf_daily_statement` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `creatorId` bigint(20) NOT NULL COMMENT '初建用户ID-制表',
--   `lastModifiedId` bigint(20) NOT NULL COMMENT '更新用户ID',
--   `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '初建时间',
--   `incomeImprest` decimal(20,4) DEFAULT '0.0000' COMMENT '现金收入-备用金',
--   `priceSumSellCash` decimal(20,4) DEFAULT '0.0000' COMMENT '现金收入-现金销售',
--   `amountReceived` decimal(20,4) DEFAULT '0.0000' COMMENT '现金收入-已收货款',
--   `incomeOther` decimal(20,4) DEFAULT '0.0000' COMMENT '现金收入-其他收入',
--   `incomeSum` decimal(20,4) DEFAULT '0.0000' COMMENT '现金收入-收入合计',
--   `incomeTaobaoAccount` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '应收明细-收入淘宝账号？金钱？',
--   `incomeTaobao` decimal(20,4) DEFAULT '0.0000' COMMENT '应收明细-淘宝?',
--   `incomeSumMon` decimal(20,4) DEFAULT '0.0000' COMMENT '应收明细-本月收入合计',
--   `incomeBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '应收明细-应收结余',
--   `dailyBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '当日余额',
--   `inBankMoney` decimal(20,4) DEFAULT '0.0000' COMMENT '入行金额',
--   `bankBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '银行结余',
--   `expenditureImprest` decimal(20,4) DEFAULT '0.0000' COMMENT '备用金余额',
--   `costManagement` decimal(20,4) DEFAULT '0.0000' COMMENT '现金支出-管理费用',
--   `priceSumComeCash` decimal(20,4) DEFAULT '0.0000' COMMENT '现金支出-采购现金货款',
--   `amountPaid` decimal(20,4) DEFAULT '0.0000' COMMENT '现金支出-已付货款',
--   `costOther` decimal(20,4) DEFAULT '0.0000' COMMENT '现金支出-其他支出',
--   `costSum` decimal(20,4) DEFAULT '0.0000' COMMENT '现金支出-支出合计',
--   `costZhifubaoAccount` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '应付明细-支出支付宝账号？金钱？',
--   `costZhifubao` decimal(20,4) DEFAULT '0.0000' COMMENT '应付明细-支付宝?',
--   `zhifubaoBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '应付明细-余额',
--   `costBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '应付明细-应收结余',
--   `dailyExpenditureImprest` decimal(20,4) DEFAULT '0.0000' COMMENT '当天备用金余额',
--   `empName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '初建员工姓名-制表',
--   `lastModifiedEmpName` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '更新员工姓名',
--   `supervisor` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '主管',
--   `wechat` varchar(100) CHARACTER SET utf8mb4 DEFAULT NULL COMMENT '微信号?',
--   `costWechat` decimal(20,4) DEFAULT '0.0000' COMMENT '微信支出?',
--   `wechatBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '余额？微信余额？',
--   `memo` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
--   PRIMARY KEY (`id`)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='出纳日报表'
-- ;

-- -- ------------------------------------------------------------------------------------------------------------------------------------------
-- -- 出纳日报表
-- -- ---------------------------------------------------------------------------------------------------------------------------------------
-- DROP TABLE IF EXISTS `erf_daily_statement`;
-- CREATE TABLE `erf_daily_statement` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `amountReceiveSum` decimal(20,4) DEFAULT '0.0000' COMMENT '应收金额，历史未收总额',
--   `amountReceived` decimal(20,4) DEFAULT '0.0000' COMMENT '已收金额',
--   `amountReceivedBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '应收余额',
--   `amountPaySum` decimal(20,4) DEFAULT '0.0000' COMMENT '应付金额，历史未付总额',
--   `amountPaid` decimal(20,4) DEFAULT '0.0000' COMMENT '已付金额',
--   `amountPaidBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '应汇余额',
--   `createdDate` char(10) NOT NULL COMMENT '初建时间',
--   `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间',
--   `memo` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
--   PRIMARY KEY (`id`)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='出纳日报表'
-- ;

-- ----------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erf_daily_statement_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER tr_erf_daily_statement_BEFORE_UPDATE BEFORE UPDATE ON erf_daily_statement FOR EACH ROW 
BEGIN
	-- 应收金额，销售订单审核通过时
	IF new.amountReceiveSum <> old.amountReceiveSum AND new.amountReceivedBalance <> old.amountReceivedBalance THEN
		IF EXISTS(SELECT 1 FROM erf_month_statement ms WHERE ms.amountReceiveSum + new.amountReceiveSum - old.amountReceiveSum < 0) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '更新月报表出现应收总额小于0情况！';
		ELSEIF EXISTS(SELECT 1 FROM erf_month_statement ms 
			WHERE ms.amountReceivedBalance + new.amountReceivedBalance - old.amountReceivedBalance < 0) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '更新月报表出现应收余额小于0情况！';
		END IF;
		-- 更新月报表应收金额和应收余额
		UPDATE erf_month_statement ms SET ms.amountReceiveSum = ms.amountReceiveSum + new.amountReceiveSum - old.amountReceiveSum
			, ms.amountReceivedBalance = ms.amountReceivedBalance + new.amountReceivedBalance - old.amountReceivedBalance
		WHERE ms.createdDate = DATE_FORMAT(CURDATE(),'%Y-%m');
	ELSEIF new.amountReceived <> old.amountReceived AND new.amountReceivedBalance <> old.amountReceivedBalance THEN
	-- 已收金额，销售订单结算时
		IF EXISTS(SELECT 1 FROM erf_month_statement ms WHERE ms.amountReceived + new.amountReceived - old.amountReceived < 0) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '更新月报表出现已收总额小于0情况！';
		ELSEIF EXISTS(SELECT 1 FROM erf_month_statement ms 
			WHERE ms.amountReceivedBalance + new.amountReceivedBalance - old.amountReceivedBalance < 0) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '更新月报表出现应收余额小于0情况！';
		END IF;
		-- 更新月报表已收金额和应收余额
		UPDATE erf_month_statement ms SET ms.amountReceived = ms.amountReceived + new.amountReceived - old.amountReceived
			, ms.amountReceivedBalance = ms.amountReceivedBalance + new.amountReceivedBalance - old.amountReceivedBalance
		WHERE ms.createdDate = DATE_FORMAT(CURDATE(),'%Y-%m');
	ELSEIF new.amountPaySum <> old.amountPaySum AND new.amountPaidBalance <> old.amountPaidBalance THEN
	-- 应付金额，采购单审核通过时
		IF EXISTS(SELECT 1 FROM erf_month_statement ms WHERE ms.amountPaySum + new.amountPaySum - old.amountPaySum < 0) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '更新月报表出现应付总额小于0情况！';
		ELSEIF EXISTS(SELECT 1 FROM erf_month_statement ms 
			WHERE ms.amountPaidBalance + new.amountPaidBalance - old.amountPaidBalance < 0) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '更新月报表出现应付余额小于0情况！';
		END IF;
		-- 更新月报表应付金额和应付余额
		UPDATE erf_month_statement ms SET ms.amountPaySum = ms.amountPaySum + new.amountPaySum - old.amountPaySum
			, ms.amountPaidBalance = ms.amountPaidBalance + new.amountPaidBalance - old.amountPaidBalance
		WHERE ms.createdDate = DATE_FORMAT(CURDATE(),'%Y-%m');
	ELSEIF new.amountPaid <> old.amountPaid AND new.amountPaidBalance <> old.amountPaidBalance THEN
	-- 已付金额，采购订单结算时
		IF EXISTS(SELECT 1 FROM erf_month_statement ms WHERE ms.amountPaid + new.amountPaid - old.amountPaid < 0) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '更新月报表出现已付总额小于0情况！';
		ELSEIF EXISTS(SELECT 1 FROM erf_month_statement ms 
			WHERE ms.amountPaidBalance + new.amountPaidBalance - old.amountPaidBalance < 0) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '更新月报表出现应付余额小于0情况！';
		END IF;
		-- 更新月报表已付金额和应付余额
		UPDATE erf_month_statement ms SET ms.amountPaid = ms.amountPaid + new.amountPaid - old.amountPaid
			, ms.amountPaidBalance = ms.amountPaidBalance + new.amountPaidBalance - old.amountPaidBalance
		WHERE ms.createdDate = DATE_FORMAT(CURDATE(),'%Y-%m');
	END IF;
END;;
DELIMITER ;

-- 
-- *****************************************************************************************************
-- 创建存储过程 p_erf_daily_statement_new, 日报表初始化
-- *****************************************************************************************************
-- DROP PROCEDURE IF EXISTS p_erf_daily_statement_new;
-- DELIMITER ;;
-- CREATE PROCEDURE p_erf_daily_statement_new(
-- )
-- BEGIN
-- 
-- 	DECLARE aEmpId BIGINT(20);
-- 	DECLARE aEmpName, aUserName VARCHAR(100);
-- 	DECLARE aReceiveBalance, aPaidBalance DECIMAL(20,4);
-- 
-- 	-- 判断是否存在当天日报表
-- 	IF NOT EXISTS(SELECT 1 FROM erf_daily_statement ds WHERE ds.createdDate = CURDATE()) THEN
-- 	
-- 		-- 获取前一天数据信息
-- 		SELECT ds.amountReceivedBalance, ds.amountPaidBalance INTO aReceiveBalance, aPaidBalance
-- 			FROM erf_daily_statement ds WHERE ds.createdDate = 
-- 			(SELECT MAX(dss.createdDate) FROM erf_daily_statement dss);
-- 
-- 		-- 新增一条数据信息
-- 		INSERT INTO erf_daily_statement(amountReceiveSum, amountReceivedBalance, amountPaySum, amountPaidBalance, createdDate)
-- 		SELECT IFNULL(aReceiveBalance,0), IFNULL(aReceiveBalance,0), IFNULL(aPaidBalance,0), IFNULL(aPaidBalance,0), CURDATE();
-- 		
-- 	END IF;
-- 
-- 	-- 判断是否存在当月月报表
-- 	IF NOT EXISTS(SELECT 1 FROM erf_month_statement ms WHERE ms.createdDate = DATE_FORMAT(CURDATE(),'%Y-%m')) THEN
-- 
-- 		-- 获取前一月数据信息
-- 		SELECT ms.amountReceivedBalance, ms.amountPaidBalance INTO aReceiveBalance, aPaidBalance
-- 			FROM erf_month_statement ms WHERE ms.createdDate = 
-- 			(SELECT MAX(mss.createdDate) FROM erf_month_statement mss);
-- 
-- 		-- 新增一条数据信息
-- 		INSERT INTO erf_month_statement(amountReceiveSum, amountReceivedBalance, amountPaySum, amountPaidBalance
-- 			, createdDate)
-- 		SELECT IFNULL(aReceiveBalance,0), IFNULL(aReceiveBalance,0), IFNULL(aPaidBalance,0), IFNULL(aPaidBalance,0)
-- 			, DATE_FORMAT(CURDATE(),'%Y-%m');
-- 	END IF;
-- 	
-- END;;
-- DELIMITER ;

-- -- ------------------------------------------------------------------------------------------------------------------------------------------
-- -- 月报表
-- -- ---------------------------------------------------------------------------------------------------------------------------------------
-- DROP TABLE IF EXISTS `erf_month_statement`;
-- CREATE TABLE `erf_month_statement` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `amountReceiveSum` decimal(20,4) DEFAULT '0.0000' COMMENT '应收金额，最新未收总额',
--   `amountReceived` decimal(20,4) DEFAULT '0.0000' COMMENT '已收金额',
--   `amountReceivedBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '应收余额',
--   `amountPaySum` decimal(20,4) DEFAULT '0.0000' COMMENT '应付金额，最新未付总额',
--   `amountPaid` decimal(20,4) DEFAULT '0.0000' COMMENT '已付金额',
--   `amountPaidBalance` decimal(20,4) DEFAULT '0.0000' COMMENT '应汇余额',
--   `createdDate` char(10) NOT NULL COMMENT '初建时间',
--   `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间',
--   `memo` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '备注',
--   PRIMARY KEY (`id`)
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='月报表'
-- ;