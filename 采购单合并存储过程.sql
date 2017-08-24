-- -- *****************************************************************************************************
-- -- 创建存储过程 p_merge_purch, 合并采购单
-- -- *****************************************************************************************************
-- DROP PROCEDURE IF EXISTS p_merge_purch;
-- DELIMITER ;;
-- CREATE PROCEDURE p_merge_purch(
-- 	pdid bigint(20) -- 采购明细ID erp_purch_detail.id 
-- 	, pid BIGINT(20) -- 新采购单ID erp_purch_bil.id
-- 	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
-- )
-- BEGIN
-- 
-- 	
-- 
-- END;;
-- DELIMITER ;
-- 
-- -- *****************************************************************************************************
-- -- 创建存储过程 p_call_merge_purch, 合并采购单
-- -- *****************************************************************************************************
-- DROP PROCEDURE IF EXISTS p_call_vendiBack_snCode_shelf;
-- DELIMITER ;;
-- CREATE PROCEDURE `p_call_vendiBack_snCode_shelf`(
-- 	pids VARCHAR(65535) CHARSET latin1 -- 采购单ID erp_purch_bil.id(集合，用xml格式) 
-- 	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
-- 	, qty INT(11) -- 采购单主表数量
-- )
-- BEGIN
-- 
-- 	DECLARE aCheck, aCost, aReceive TINYINT;
-- 	DECLARE newPId, pId, vId, iId, aSupplier, aGeoId BIGINT(20);
-- 	DECLARE aZoneNum, aInquiryCode VARCHAR(100);
-- 	DECLARE aTakeGeoTel, aMemo VARCHAR(1000);
-- 	DECLARE sTime, iTime, nTime datetime;
-- 	DECLARE i INT DEFAULT 1;
-- 	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
-- 		BEGIN
-- 			ROLLBACK;
-- 			RESIGNAL;
-- 		END;
-- 	
-- 	START TRANSACTION;
-- 
-- 	-- 获取第一条采购单信息
-- 	SELECT a.erp_vendi_bil_id, a.erp_inquiry_bil_id, a.supplierId, a.isCheck, a.isCost, a.isReceive
-- 		, a.zoneNum, a.inquiryCode, a.sncodeTime , a.inTime, a.needTime
-- 		, a.`erc$telgeo_contact_id`, a.takeGeoTel, a.memo
-- 	INTO vId, iId, aSupplier, aCheck, aCost, aReceive
-- 		, aZoneNum, aInquiryCode, sTime, iTime, nTime
-- 		, aGeoId, aTakeGeoTel, aMemo
-- 	FROM erp_purch_bil a WHERE a.id = ExtractValue(aids, '//a[$1]');
-- 	-- 新增一条采购单主表
-- 	INSERT INTO erp_purch_bil(erp_vendi_bil_id, erp_inquiry_bil_id, supplierId, zoneNum, inquiryCode, lastModifiedId
-- 		, needTime, erc$telgeo_contact_id, takeGeoTel, memo)
-- 	SELECT vId, iId, aSupplier, aZoneNum, aInquiryCode, uId
-- 		, nTime, aGeoId, aTakeGeoTel, aMemo;
-- 	-- 记录新主表ID
-- 	SET newPId = LAST_INSERT_ID();
-- 	-- 循环设置销售明细外键
-- 	WHILE i < qty+1 DO
-- 		-- 重新设置销售明细外键
-- 		SET pId = ExtractValue(aids, '//a[$i]');
-- 		-- 设置计数器
-- 		SET i = i+1;
-- 	END WHILE;
-- 
-- 	COMMIT;  
-- 
-- END;;
-- DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_group_purch, 按供应商分采购单
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_group_purch;
DELIMITER ;;
CREATE PROCEDURE p_group_purch(
	pid bigint(20) -- 采购主表ID erp_purch_bil.id 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
)
BEGIN

	DECLARE aEmpId bigint(20);
	DECLARE aEmpName, aUserName varchar(100);
	DECLARE aCheck, aCost, aReceive tinyint;
	DECLARE msg varchar(1000);

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

	-- 开启事务
	START TRANSACTION;

	-- 获取采购单状态
	SELECT p.isCheck, p.isCost, p.isReceive INTO aCheck, aCost, aReceive FROM erp_purch_bil p WHERE p.id = pid;
	-- 根据采购单状态判断是否能拆分
	IF aCheck > -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单已进入审核流程，不能拆分！';
	ELSEIF aCost > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单已确认汇款，不能拆分！';
	ELSEIF aReceive > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '仓库已签收该采购单商品，不能拆分！';
	END IF;
	-- 判断采购明细是否存在没有供应商
	IF EXISTS(SELECT 1 FROM erp_purch_detail pd WHERE ISNULL(pd.supplierId) AND pd.erp_purch_bil_id = pid LIMIT 1) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请先指定该单全部配件的供应商！';
	END IF;

	-- 判断用户是否合理
	IF NOT EXISTS(SELECT 1 FROM autopart01_security.sec$user a WHERE a.ID = uId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效用户操作采购单拆分！';
	ELSE
		CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);
	END IF;

	-- 插入新采购单主表
	INSERT INTO erp_purch_bil( erp_vendi_bil_id, erp_inquiry_bil_id, priceSumCome, supplierId, creatorId, createdDate
		, createdBy, empId, empName, memo, needTime
		, lastModifiedDate, lastModifiedId, lastModifiedEmpId, lastModifiedEmpName, lastModifiedBy
		, erp_payment_type_id, inquiryCode)
	SELECT p.erp_vendi_bil_id, p.erp_inquiry_bil_id, sum(pd.amt), pd.supplierId, uId, now()
		, aUserName, aEmpId, aEmpName, concat('销售订单审核库存不足自动转入。'), p.needTime
		, now(), uId, aEmpId, aEmpName, aUserName
		, pd.erp_payment_type_id, p.inquiryCode
	FROM erp_purch_bil p
	INNER JOIN erp_purch_detail pd ON pd.erp_purch_bil_id = pid AND pd.erp_purch_bil_id = p.id
	GROUP BY pd.supplierId, pd.erp_payment_type_id
	;
	if ROW_COUNT() = 0 THEN
		set msg = concat('采购单（编号：', pid,'）未能拆分成功!');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;

	-- 更新采购明细表erp_purch_bil_id字段
	UPDATE erp_purch_detail pd INNER JOIN erp_purch_bil p ON p.erp_vendi_bil_id = pd.erp_vendi_bil_id AND p.supplierId = pd.supplierId
	AND p.erp_payment_type_id = pd.erp_payment_type_id
	SET pd.erp_purch_bil_id = p.id
	WHERE pd.erp_purch_bil_id = pid
	;
	if ROW_COUNT() = 0 THEN
		set msg = concat('采购单（编号：', pid,'）明细更新不成功!');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
	
	-- 删除旧采购单状态表
	DELETE FROM erp_purch_bilwfw WHERE billId = pid;
	-- 删除旧采购单主表
	DELETE FROM erp_purch_bil WHERE id = pid;

	-- 提交
	COMMIT;

END;;
DELIMITER ;

-- -- *****************************************************************************************************
-- -- 创建存储过程 p_group_purch_detail, 按供应商分采购单(内层)(作废)
-- -- *****************************************************************************************************
-- DROP PROCEDURE IF EXISTS p_group_purch_detail;
-- DELIMITER ;;
-- CREATE PROCEDURE p_group_purch_detail(
-- 	pdid bigint(20) -- 采购明细ID erp_purch_detail.id 
-- 	, spid bigint(20) -- 供应商支付方式ID erp_supplier_payment.id
-- 	, aqty int -- 配件数量
-- 	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
-- )
-- BEGIN
-- 
-- 	DECLARE aEmpId, aSupplierId, aPayId bigint(20);
-- 	DECLARE aEmpName, aUserName varchar(100);
-- 	DECLARE aCheck, aReceive tinyint;
-- 	DECLARE aCostTime, aInTime datetime;
-- 	DECLARE msg varchar(1000);
-- 
-- 	-- 判断用户是否合理
-- 	IF NOT EXISTS(SELECT 1 FROM autopart01_security.sec$user a WHERE a.ID = uId) THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效用户操作采购明细拆分！';
-- 	ELSE
-- 		CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);
-- 	END IF;
-- 
-- 	-- 获取供应商ID和支付方式ID
-- 	SELECT sp.supplierId, sp.erp_payment_type_id INTO aSupplierId, aPayId FROM erp_supplier_payment sp WHERE sp.id = spid;
-- 
-- 	-- 判断供应商是否存在
-- 	IF NOT EXISTS(SELECT 1 FROM autopart01_crm.`erc$supplier` a WHERE a.id = aSupplierId) THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效供应商操作采购明细拆分！';
-- 	ELSEIF aqty < 1 THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效数量操作采购明细拆分！';
-- 	END IF;
-- 
-- 	-- 新增新的采购明细
-- 	INSERT INTO erp_purch_detail(erp_purch_bil_id, erp_vendi_bil_id, erp_sales_detail_id, supplierId
-- 		, goodsId, ers_packageAttr_id, packageQty, packageUnit
-- 		, qty, unit, packagePrice, price, amt
-- 		, createdDate, updatedDate, lastModifiedDate, erp_payment_type_id
-- 		, lastModifiedId, lastModifiedEmpId, lastModifiedEmpName, lastModifiedBy)
-- 	SELECT pd.erp_purch_bil_id, pd.erp_vendi_bil_id, pd.erp_sales_detail_id, aSupplierId
-- 		, pd.goodsId, pd.ers_packageAttr_id, aqty, pd.packageUnit
-- 		, aqty, pd.unit, pd.packagePrice, pd.price, aqty*pd.price
-- 		, NOW(), NOW(), NOW(), aPayId
-- 		, uId, aEmpId, aEmpName, aUserName
-- 	FROM erp_purch_detail pd WHERE pd.id = pdid
-- 	;
-- 	if ROW_COUNT() <> 1 THEN
-- 		set msg = concat(msg, '未能成功拆分采购明细！');
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
-- 	end if;
-- END;;
-- DELIMITER ;
-- 
-- -- *****************************************************************************************************
-- -- 创建存储过程 p_call_group_purch_detail, 按供应商分采购单(外层)(作废)
-- -- *****************************************************************************************************
-- DROP PROCEDURE IF EXISTS p_call_group_purch_detail;
-- DELIMITER ;;
-- CREATE PROCEDURE p_call_group_purch_detail(
-- 	aids VARCHAR(65535) CHARSET latin1 -- <a><s><q></a>(供应商支付方式、配件数量、价格集合，用xml格式) 
-- 	, pdid bigint(20) -- 采购明细ID erp_purch_detail.id
-- 	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
-- 	, qty INT(11) -- 拆分数量
-- )
-- BEGIN
-- 
-- 	DECLARE i INT DEFAULT 1;
-- 	DECLARE pdQty INT;
-- 	DECLARE aCheck, aReceive tinyint;
-- 	DECLARE aCostTime, aInTime datetime;
-- 	DECLARE aEmpId, pid bigint(20);
-- 	DECLARE aEmpName, aUserName varchar(100);
-- 	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
-- 		BEGIN
-- 			ROLLBACK;
-- 			RESIGNAL;
-- 		END;
-- 	
-- 	START TRANSACTION;
-- 
-- 	-- 判断用户是否合理
-- 	IF NOT EXISTS(SELECT 1 FROM autopart01_security.sec$user a WHERE a.ID = uId) THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效用户操作采购明细拆分！';
-- 	ELSE
-- 		CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);
-- 	END IF;
-- 
-- 	-- 获取原采购、明细信息
-- 	SELECT p.isCheck, pd.costTime, pd.isReceive, pd.inTime, pd.qty, p.id 
-- 	INTO aCheck, aCostTime, aReceive, aInTime, pdQty, pid
-- 	FROM erp_purch_detail pd INNER JOIN erp_purch_bil p ON p.id = pd.erp_purch_bil_id
-- 	WHERE pd.id = pdid;
-- 	-- 根据采购单状态判断是否能拆分
-- 	IF aCheck > -1 THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单已进入审核流程，不能拆分！';
-- 	ELSEIF aCostTime > 0 THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购明细已确认汇款，不能拆分！';
-- 	ELSEIF aReceive > 0 THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '仓库已签收该采购单商品，不能拆分！';
-- 	ELSEIF aInTime > 0 THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单商品已完成进仓，不能拆分！';
-- 	END IF;
-- 
-- 	-- 初始化配件数量
-- 	SET @x:=0;
-- 
-- 	-- 更加拆分数量进行拆分
-- 	WHILE i < qty+1 DO
-- 		SET @x:=@x+ExtractValue(aids, '/descendant-or-self::q[$i]');
-- 		CALL p_group_purch_detail(pdid, ExtractValue(aids, '/descendant-or-self::s[$i]')
-- 			, ExtractValue(aids, '/descendant-or-self::q[$i]')
-- 			, uId);
-- 		SET i = i+1;
-- 	END WHILE;
-- 	
-- 	IF @x <> pdQty THEN
-- 		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定正确的拆分数量！';
-- 	END IF;
-- 
-- 	-- 删除旧采购明细
-- 	DELETE FROM erp_purch_detail WHERE id = pdid;
-- 	-- 记录操作
-- 	insert into erp_purch_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
-- 	SELECT pid, 'distribution', uId, aEmpId, aEmpName, aUserName, CONCAT('采购明细（编号：', pdid, '）拆分成功！')
-- 	;
-- 
-- 	COMMIT; 
-- 
-- END;;
-- DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_group_purch_detail, 按供应商分采购单(内层)
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_group_purch_detail;
DELIMITER ;;
CREATE PROCEDURE p_group_purch_detail(
	pdid bigint(20) -- 采购明细ID erp_purch_detail.id 
	, sid bigint(20) -- 供应商ID supplierId
	, aqty int -- 配件数量
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
)
BEGIN

	DECLARE aEmpId bigint(20);
	DECLARE aEmpName, aUserName varchar(100);
	DECLARE msg varchar(1000);

	-- 获取用户信息
	CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);

	-- 判断供应商是否存在
	IF NOT EXISTS(SELECT 1 FROM autopart01_crm.`erc$supplier` a WHERE a.id = sid) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效供应商操作采购明细拆分！';
	ELSEIF aqty < 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效数量操作采购明细拆分！';
	END IF;

	-- 新增新的采购明细
	INSERT INTO erp_purch_detail(erp_purch_bil_id, erp_vendi_bil_id, erp_sales_detail_id, supplierId
		, goodsId, ers_packageAttr_id, packageQty, packageUnit
		, qty, unit, packagePrice, price, amt
		, createdDate, updatedDate, lastModifiedDate
		, lastModifiedId, lastModifiedEmpId, lastModifiedEmpName, lastModifiedBy)
	SELECT pd.erp_purch_bil_id, pd.erp_vendi_bil_id, pd.erp_sales_detail_id, sid
		, pd.goodsId, pd.ers_packageAttr_id, aqty, pd.packageUnit
		, aqty, pd.unit, pd.packagePrice, pd.price, aqty*pd.price
		, NOW(), NOW(), NOW()
		, uId, aEmpId, aEmpName, aUserName
	FROM erp_purch_detail pd WHERE pd.id = pdid
	;
	if ROW_COUNT() <> 1 THEN
		set msg = concat(msg, '未能成功拆分采购明细！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	end if;
END;;
DELIMITER ;

-- *****************************************************************************************************
-- 创建存储过程 p_call_group_purch_detail, 按供应商分采购单(外层)
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_call_group_purch_detail;
DELIMITER ;;
CREATE PROCEDURE p_call_group_purch_detail(
	aids VARCHAR(65535) CHARSET latin1 -- <a><s><q></a>(供应商、配件数量、价格集合，用xml格式) 
	, pdid bigint(20) -- 采购明细ID erp_purch_detail.id
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, qty INT(11) -- 拆分数量
)
BEGIN

	DECLARE i INT DEFAULT 1;
	DECLARE pdQty INT;
	DECLARE aCheck, aReceive tinyint;
	DECLARE aCostTime, aInTime datetime;
	DECLARE aEmpId, pid bigint(20);
	DECLARE aEmpName, aUserName varchar(100);
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;
	
	START TRANSACTION;

	-- 获取用户信息
	CALL p_get_userInfo(uId, aEmpId, aEmpName, aUserName);

	-- 获取原采购、明细信息
	SELECT p.isCheck, pd.costTime, pd.isReceive, pd.inTime, pd.qty, p.id 
	INTO aCheck, aCostTime, aReceive, aInTime, pdQty, pid
	FROM erp_purch_detail pd INNER JOIN erp_purch_bil p ON p.id = pd.erp_purch_bil_id
	WHERE pd.id = pdid;
	-- 根据采购单状态判断是否能拆分
	IF aCheck > -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单已进入审核流程，不能拆分！';
	ELSEIF aCostTime > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购明细已确认汇款，不能拆分！';
	ELSEIF aReceive > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '仓库已签收该采购单商品，不能拆分！';
	ELSEIF aInTime > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该采购单商品已完成进仓，不能拆分！';
	END IF;

	-- 初始化配件数量
	SET @x:=0;

	-- 更加拆分数量进行拆分
	WHILE i < qty+1 DO
		SET @x:=@x+ExtractValue(aids, '/descendant-or-self::q[$i]');
		CALL p_group_purch_detail(pdid, ExtractValue(aids, '/descendant-or-self::s[$i]')
			, ExtractValue(aids, '/descendant-or-self::q[$i]')
			, uId);
		SET i = i+1;
	END WHILE;
	
	IF @x <> pdQty THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定正确的拆分数量！';
	END IF;

	-- 删除旧采购明细
	DELETE FROM erp_purch_detail WHERE id = pdid;
	-- 记录操作
	insert into erp_purch_bilwfw(billId, billstatus, userid, empId, empName, userName, name)
	SELECT pid, 'distribution', uId, aEmpId, aEmpName, aUserName, CONCAT('采购明细（编号：', pdid, '）拆分成功！')
	;

	COMMIT; 

END;;
DELIMITER ;

-- CALL p_call_group_purch_detail(
-- 	'<a><s>s1</s><p>1.1</p><q>q1</q></a><a><s>s2</s><p>2.2</p><q>q2</q></a><a><s>s3</s><p>3.3</p><q>q3</q></a>',
-- 	1, 1, 3)
-- ;