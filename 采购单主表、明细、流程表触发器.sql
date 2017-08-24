-- -------------------------------------------------------------------------------------------
-- 采购单主表
-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bil_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_bil` FOR EACH ROW
BEGIN

	declare aid bigint(20);
	DECLARE aName, aUserName varchar(100);

	if exists(select 1 from autopart01_crm.`erc$supplier` a where a.id = new.supplierId limit 1) then
		set new.zoneNum = (select a.zonenum from autopart01_crm.`erc$supplier` a where a.id = new.supplierId);
		if isnull(new.zoneNum) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未指定供应商的电话区号！',MYSQL_ERRNO = 1001;
		end if;
	else
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增采购单，必须指定有效的供应商！';
	end if;

	-- 最后修改用户变更，获取相关信息
	if isnull(new.lastModifiedId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建采购单，必须指定最后修改用户！';
	elseif isnull(new.lastModifiedEmpId) then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
		if new.creatorId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建采购单，创建者和最后修改用户必须是同一人！';
		elseif isnull(new.empId) THEN
			set new.empId = new.lastModifiedEmpId, new.empName = new.lastModifiedEmpName, new.createdBy = new.lastModifiedBy;
		end if;
	end if;

	if new.erc$telgeo_contact_id > 0 THEN
		if exists(select 1 from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id) then
			if isnull(new.takeGeoTel) then
				-- 生成提货地址文本
				set new.takeGeoTel = (select concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
					from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id
				);
			end if;
		ELSE
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增采购单时，提货地址和电话无效！';
		end if;
	end if;

	-- 生成code 区号+8位日期+4位员工id+4位流水
	set new.code = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.creatorId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_purch_bil a 
				where date(a.createdDate) = date(new.createdDate) and a.creatorId = new.creatorId), 0
			) + 1, 4, 0)
	);

	-- 修改最新操作时间
	SET new.isCheck = -1, new.createdDate = CURRENT_TIMESTAMP(), new.lastModifiedDate = CURRENT_TIMESTAMP();

END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bil_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_AFTER_INSERT` AFTER INSERT ON `erp_purch_bil` FOR EACH ROW 
BEGIN
	-- 写入采购状态表
	insert into erp_purch_bilwfw(`billId`,`billStatus`,`userId`, empId, empName, userName,`name`, memo) 
	select new.id, 'justcreated', new.`creatorId`, new.lastModifiedEmpId, new.lastModifiedEmpName, new.createdBy, '刚刚创建',
		, concat('员工（编号：', new.lastModifiedEmpId, ' 姓名：', new.lastModifiedEmpName, '）创建采购单主表（编号：', new.id,'）');
	if ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能写入采购订单状态表!';
	end if;
END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bil_BEFORE_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_BEFORE_UPDATE` BEFORE UPDATE ON `erp_purch_bil` FOR EACH ROW 
BEGIN
	declare aid bigint(20);
	DECLARE aName, aUserName varchar(100);

	if new.lastModifiedId <> old.lastModifiedId then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aId, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	end if;
	
	IF old.isCheck = -1 AND new.isCheck = 0 THEN -- 提交出纳审核(生成汇款单-->出纳)
		IF ISNULL(new.erc$telgeo_contact_id) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单提交出纳审核时，必须指定提货地址！';
		ELSEIF new.supplierId <> old.supplierId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单提交出纳审核时，不能变更供应商！';
		END IF;
		insert into erp_purch_bilwfw(`billId`,`billStatus`,`userId`, empId, empName, userName,`name`)
		select new.id, 'submitthatview', new.`creatorId`, new.lastModifiedEmpId, new.lastModifiedEmpName, new.createdBy, '提交出纳待审';
	ELSEIF old.isCheck = 0 AND new.isCheck = -1 THEN -- 出纳审核退回
		IF new.supplierId <> old.supplierId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单出纳退回审核时，不能变更供应商！';
		END IF;
		insert into erp_purch_bilwfw(`billId`,`billStatus`,`userId`, empId, empName, userName,`name`)
		select new.id, 'submitBack', new.`creatorId`, new.lastModifiedEmpId, new.lastModifiedEmpName, new.createdBy, '出纳审核退回';
	ELSEIF old.isCheck = 0 AND new.isCheck = 1 THEN -- 出纳审核通过(生成提货单-->配送部)
		IF new.supplierId <> old.supplierId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单出纳审核通过时，不能变更供应商！';
		END IF;
		-- 登记审核人
		set new.checkUserId = new.lastModifiedId, new.checkEmpId = new.lastModifiedEmpId, new.checkEmpName = new.lastModifiedEmpName;

		insert into erp_purch_bilwfw(`billId`,`billStatus`,`userId`, empId, empName, userName,`name`)
		select new.id, 'checked', new.`creatorId`, new.lastModifiedEmpId, new.lastModifiedEmpName, new.createdBy, '出纳审核通过';
	ELSEIF ISNULL(old.sncodeUserId) AND EXISTS(new.sncodeUserId) THEN -- 商品生码
		-- 登记生码时间
		SET sncodeTime = NOW();
		
		insert into erp_purch_bilwfw(`billId`,`billStatus`,`userId`, empId, empName, userName,`name`)
		select new.id, 'createCode', new.`creatorId`, new.lastModifiedEmpId, new.lastModifiedEmpName, new.createdBy, '商品生码';
	ELSEIF ISNULL(old.costUserId) AND EXISTS(new.costUserId) THEN	-- 汇款确认
		IF new.lastModifiedId <> old.checkUserId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '只能由出纳确认汇款！';
		END IF;
		-- 登记汇款信息
		set new.costTime = NOW(), new.costEmpId = new.lastModifiedEmpId, new.costEmpName = new.lastModifiedEmpName;
		
		insert into erp_purch_bilwfw(`billId`,`billStatus`,`userId`, empId, empName, userName,`name`)
		select new.id, 'cost', new.`creatorId`, new.lastModifiedEmpId, new.lastModifiedEmpName, new.createdBy, '汇款确认';
	ELSEIF ISNULL(old.inTime) AND EXISTS(new.inTime) THEN	-- 进仓完成
		insert into erp_purch_bilwfw(`billId`,`billStatus`,`userId`, empId, empName, userName,`name`)
		select new.id, 'in', new.`creatorId`, new.lastModifiedEmpId, new.lastModifiedEmpName, new.createdBy, '配件进仓完成';
	ELSE
		IF new.erc$telgeo_contact_id > 0 and 
			(isnull(old.erc$telgeo_contact_id) or new.erc$telgeo_contact_id <> old.erc$telgeo_contact_id)THEN
			SET new.takeGeoTel = (SELECT concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
				FROM autopart01_crm.erc$telgeo_contact a WHERE a.id = new.erc$telgeo_contact_id
			);
		END IF;
		-- 记录操作
		insert into erp_vendi_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
				, new.lastModifiedBy, '修改采购单主表';
	END IF;

	-- 最新操作时间
	SET new.lastModifiedDate = CURRENT_TIMESTAMP();

END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bil_AFTER_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_AFTER_UPDATE` AFTER UPDATE ON `erp_purch_bil` FOR EACH ROW 
BEGIN
-- 	IF old.isCheck = -1 AND new.isCheck = 0 THEN	-- 提交出纳待审，生成汇款单(视图实现)-->出纳
-- 	END IF;
	IF old.isCheck = 0 AND new.isCheck = 1 THEN	-- 出纳审核通过，生成采购提货表-->配送部
		insert into erp_purch_pick(erp_purch_bil_id, userId, empId, empName, opTime, erc$telgeo_contact_id, takeGeoTel)
		select new.id, new.creatorId, new.empId, new.empName, CURRENT_TIMESTAMP(), new.erc$telgeo_contact_id, new.takeGeoTel;
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能生成采购提货单!';
		end if;
	ELSEIF ISNULL(old.sncodeUserId) AND EXISTS(new.sncodeUserId) THEN	-- 商品生码-->用于仓管扫码进仓
		call p_purchDetail_snCode(new.id);
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能生成商品二维码!';
		end if;
	END IF;

END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bil_BEFORE_DELETE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_BEFORE_DELETE` BEFORE DELETE ON `erp_purch_bil` FOR EACH ROW 
BEGIN
	if old.costTime > '' THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单已汇款确认，不能删除！';
	ELSEIF old.inTime > '' THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单已进仓完成，不能删除！';
	ELSEIF old.sncodeUserId > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单已生成二维码，不能删除！';
	ELSEIF old.isCheck > -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单已提交待审或审核通过，不能删除！';
	END IF;
END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_detail_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_detail` FOR EACH ROW 
BEGIN
	DECLARE msg varchar(1000);
	DECLARE aCheck TINYINT;
	DECLARE pId, vId, aId BIGINT;
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE cTime, iTime, sTime datetime;

	SET msg = concat('采购订单（编号：', new.erp_purch_bil_id, ', ）');
	SELECT a.isCheck, a.costTime, a.inTime, a.sncodeTime, a.erp_purch_bil_id, a.erp_vendi_bil_id
	INTO aCheck, cTime, iTime, sTime, pId, vId
	FROM erp_purch_bil a WHERE a.id = new.erp_purch_bil_id;

	IF cTime > '' THEN
		set msg = concat(msg, '已汇款，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF iTime > '' THEN
		set msg = concat(msg, '已进仓，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF sTime > '' THEN
		set msg = concat(msg, '已生成二维码，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		set msg = concat(msg, '已进入提交待审或审核通过，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(vId) AND EXISTS(pId) THEN
		if isnull(new.ers_packageAttr_id) THEN
			set msg = concat(msg, '追加采购明细，必须指定有效的包装！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif isnull(new.packageQty) or new.packageQty = 0 THEN
			set msg = concat(msg, '追加采购明细，必须指定有效的数量！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif isnull(new.packagePrice) or new.packageQty = 0 THEN
			set msg = concat(msg, '追加采购明细，必须指定有效的单价！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		elseif isnull(new.lastModifiedId) or new.lastModifiedId = 0 then
			set msg = concat(msg, '追加采购明细，必须指定有效的创建人！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;

		-- 最后修改用户变更，获取相关信息
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aId, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;

		-- 获取包装的相关信息
		SELECT a.actualQty, a.packageUnit, a.goodsId into aQty, aPackageUnit, aGoosId 
		FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;
		if isnull(aQty) THEN
			set msg = concat(msg, '新增明细配件，必须指定包装！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		end if;

		-- 最新进货价并计算进货金额、售价、销售金额
		set new.packageUnit = aPackageUnit, new.qty = aQty * new.packageQty, new.goodsId = aGoosId
			, new.unit =(select a.unit from erp_goods a where a.id = aGoosId)
			, new.amt = new.packageQty * new.packagePrice, new.price = new.packagePrice / aQty
			, new.createdDate = CURRENT_TIMESTAMP(), new.updatedDate = CURRENT_TIMESTAMP(), new.lastModifiedDate = CURRENT_TIMESTAMP()
			;

	END IF;
END;;
DELIMITER ;

-- -------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bilwfw_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_bilwfw` FOR EACH ROW
BEGIN
	set new.opTime = now();
	IF ISNULL(new.memo) THEN 
		SET new.memo = concat('员工（编号：', new.empId, ' 姓名：', new.empName, '）采购单（编号：', new.billId,'）', new.name);
	END IF;
END;;
DELIMITER ;