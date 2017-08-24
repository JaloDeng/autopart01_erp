SET FOREIGN_KEY_CHECKS =0;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	销售退回主表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_vendi_back;
CREATE TABLE `erp_vendi_back` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `isSubmit` tinyint(4) DEFAULT '0' COMMENT '仓库是否签收 0：未签收，不可进仓 1：已签收，可以进仓',
  `isCheck` tinyint(4) DEFAULT '-1' COMMENT '是否提交审核。-1：可以更改；0：提交待审，客服不能更改 1：审核通过，不能更改',
  `erp_vendi_bil_id` bigint(20) NOT NULL COMMENT '来源单编码，销售订单ID',
  `erp_inquiry_bil_id` bigint(20) DEFAULT NULL COMMENT '询价单ID 冗余',
  `customerId` bigint(20) NOT NULL COMMENT '客户ID',
  `creatorId` bigint(20) DEFAULT NULL COMMENT '初建用户ID',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID',
  `lastModifiedId` bigint(20) NOT NULL COMMENT '最新操作用户ID',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新操作员工ID',
  `checkUserId` bigint(20) DEFAULT NULL COMMENT '审核用户ID',
  `checkEmpId` bigint(20) DEFAULT NULL COMMENT '审核员工ID',
  `costUserId` bigint(20) DEFAULT NULL COMMENT '退款用户ID',
  `costEmpId` bigint(20) DEFAULT NULL COMMENT '退款员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '初建员工姓名',
  `createdBy` varchar(255) DEFAULT NULL COMMENT '初建登录账户名称',
  `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新操作员工姓名',
  `lastModifiedBy` varchar(255) DEFAULT NULL COMMENT '最新操作登录账户名称',
  `checkEmpName` varchar(100) DEFAULT NULL COMMENT '审核员工姓名，跟单审核',
  `costEmpName` varchar(100) DEFAULT NULL COMMENT '退款员工姓名，出纳退款',
  `zoneNum` varchar(30) DEFAULT NULL COMMENT '客户所在地区的区号 触发器获取',
  `code` varchar(100) DEFAULT NULL COMMENT '单号 新增时触发器生成',
  `inquiryCode` varchar(100) DEFAULT NULL COMMENT '询价单号，冗余',
  `payAccount` varchar(100) DEFAULT NULL COMMENT '客户收款账号，出纳退款',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '初建时间',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间',
  `checkTime` datetime DEFAULT NULL COMMENT '审核时间',
  `costTime` datetime DEFAULT NULL COMMENT '退款时间',
  `inTime` datetime DEFAULT NULL COMMENT '进仓时间',
  `priceSumCome` decimal(20,4) DEFAULT '0.0' COMMENT '进价金额总计',
  `priceSumSell` decimal(20,4) DEFAULT '0.0' COMMENT '售价金额总计，退货金额',
  `priceSumShip` decimal(20,4) DEFAULT '0.0' COMMENT '运费金额总计',
  `needTime` datetime DEFAULT NULL COMMENT '期限时间',
  `erc$telgeo_contact_id` bigint(20) DEFAULT NULL COMMENT '公司自提，提货地址和电话_id',
  `takeGeoTel` varchar(1000) DEFAULT NULL COMMENT '提货地址和电话；--这里用文本不用ID，防止本单据流程中地址被修改了',
  `reason` varchar(255) DEFAULT NULL COMMENT '客户退货原因',
  `memo` varchar(2000) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `erp_vendi_back_code_idx` (`code`) USING BTREE,
  KEY `erp_vendi_back_creatorId_idx` (`creatorId`) USING BTREE,
  KEY `erp_vendi_back_customerId_idx` (`customerId`) USING BTREE,
  KEY `erp_vendi_back_erp_inquiry_bil_idx` (`erp_inquiry_bil_id`) USING BTREE,
  KEY `erp_vendi_back_erp_vendi_bil_idx` (`erp_vendi_bil_id`) USING BTREE,
  KEY `erp_vendi_back_inquiryCode_idx` (`inquiryCode`) USING BTREE,
	CONSTRAINT `fk_erp_vendi_back_erp_vendi_bil_id` FOREIGN KEY (`erp_vendi_bil_id`) 
		REFERENCES `erp_vendi_bil` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='销售退货单主表'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_back` FOR EACH ROW BEGIN
	DECLARE aid, aCustomerId, aInquiryId, aTelgeo_contact_id, sOutUserId BIGINT(20);
	DECLARE aName, aUserName, aZoneNum, aInquiryCode varchar(100);
	DECLARE aPriceSumSell DECIMAL(20,4);
	DECLARE aTakeGeoTel VARCHAR(1000);
	DECLARE sCheck TINYINT;

	IF ISNULL(new.reason) OR new.reason = '' THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售退货单，必须指定退货原因！',MYSQL_ERRNO = 1001;
	END IF;

	-- 根据选取的销售订单自动写入相关信息
	IF EXISTS(SELECT 1 FROM erp_vendi_bil a WHERE a.id = new.erp_vendi_bil_id) THEN
		SELECT a.erp_inquiry_bil_id, a.customerId, a.zoneNum, a.priceSumSell
			, a.erc$telgeo_contact_id, a.takeGeoTel, a.inquiryCode, a.outUserId, a.isCheck
		INTO aInquiryId, aCustomerId, aZoneNum, aPriceSumSell
			, aTelgeo_contact_id, aTakeGeoTel, aInquiryCode, sOutUserId, sCheck
		FROM erp_vendi_bil a WHERE a.id = new.erp_vendi_bil_id;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售退货单时，必须选择有效销售订单', MYSQL_ERRNO = 1001;
	END IF;

	IF ISNULL(sOutUserId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '选择销售单没有出仓，不能生成退货单', MYSQL_ERRNO = 1001;
	ELSEIF sCheck <> 1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '选择销售单没有审核通过，不能生成退货单', MYSQL_ERRNO = 1001;
	END IF;
	
	-- 获取客户所在地区的区号
	if exists(select 1 from autopart01_crm.`erc$customer` a where a.id = aCustomerId limit 1) then
		set new.zoneNum = aZoneNum;
		if isnull(new.zoneNum) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未指定客户的电话区号！',MYSQL_ERRNO = 1001;
		end if;
		-- 判断销售退货单客户是否与销售单客户匹配
		IF aCustomerId <> new.customerId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售退货单与销售单的客户不匹配',MYSQL_ERRNO = 1001;
		ELSEIF aPriceSumSell < new.priceSumSell THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '退货总金额不能大于销售总金额',MYSQL_ERRNO = 1001;
		END IF;
	else
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售退货单，必须指定有效的客户！';
	end if;

	-- 最后修改用户变更，获取相关信息
	if isnull(new.lastModifiedId) THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新建销售退货单，必须指定最后修改用户！';
	elseif isnull(new.lastModifiedEmpId) then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName,
				new.creatorId = new.lastModifiedId, new.empId = aid, new.empName = aName, new.createdBy = aUserName;
	end if;
	
	-- 写入相关字段信息
	SET new.erp_inquiry_bil_id = aInquiryId, new.erc$telgeo_contact_id = aTelgeo_contact_id, new.takeGeoTel = aTakeGeoTel
			, new.createdDate = NOW(), new.lastModifiedDate = NOW(), new.inquiryCode = aInquiryCode;

	-- 生成code 区号+8位日期+4位员工id+4位流水
	set new.code = concat(new.zoneNum, date_format(NOW(),'%Y%m%d'), LPAD(new.creatorId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_vendi_back a 
				where date(a.createdDate) = date(NOW()) and a.creatorId = new.creatorId), 0
			) + 1, 4, 0)
	);

	if isnull(new.isSubmit) then
		set new.isSubmit = 0;
	end if;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_vendi_back_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_AFTER_INSERT` AFTER INSERT ON `erp_vendi_back` FOR EACH ROW BEGIN
	-- 写入销售退货单流程状态表
	insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.id, 'justcreated', new.creatorId, new.empId, new.empName, new.createdBy
				, CONCAT('刚刚创建，对应销售订单（编号：', new.erp_vendi_bil_id, '）');
	-- 新增销售退货提货单
	INSERT INTO erp_vendi_back_pick(erp_vendi_back_id, userId, empId, userName, empName
		, opTime, lastModifiedId, lastModifiedDate, inquiryCode, erc$telgeo_contact_id, takeGeoTel)
	SELECT new.id, new.creatorId, new.empId, new.createdBy, new.empName
		, NOW(), new.lastModifiedId, NOW(), new.inquiryCode, new.erc$telgeo_contact_id, new.takeGeoTel;
	if ROW_COUNT() = 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售退货单时，无法添加销售退货提货单！';
	end if;
	insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.id, 'justcreated', new.creatorId, new.empId, new.empName, new.createdBy
				, CONCAT('刚刚创建销售退货提货单，对应销售退货单（编号：', new.id, '）');
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_back` FOR EACH ROW BEGIN
	declare aid bigint(20);
	DECLARE aName, aUserName varchar(100);
	DECLARE aPriceSumSell decimal(20, 4);
	
	-- 最后修改用户变更，获取相关信息
	if new.lastModifiedId <> old.lastModifiedId then
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	end if;

	IF ISNULL(old.costUserId) AND new.costUserId > 0 THEN -- 退款确认
		-- 根据单据状态判断是否可以确认退款
		IF new.isCheck <> 1 THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '没有审核通过，不能确认退款！', MYSQL_ERRNO = 1001;
		ELSEIF ISNULL(new.inTime) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '没有完成进仓，不能确认退款', MYSQL_ERRNO = 1001;
		ELSEIF new.isSubmit <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '仓库没有签收，不能确认退款', MYSQL_ERRNO = 1001;
		ELSEIF new.costUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '退款确认时，最新修改员工必须与退款确认员工相同！', MYSQL_ERRNO = 1001;
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '退款确认时不能变更客户！！';
		ELSEIF old.payAccount <> new.payAccount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '退款确认时不能变更客户收款账号！！';
		END IF;
		-- 记录退款确认人，确认时间
		set new.costEmpId = aid, new.costEmpName = aName, new.costTime = NOW();
		-- 记录操作
		insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'cost', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '退款确认';
	ELSEIF old.isCheck = 0 AND new.isCheck = 1 THEN -- 审核通过(生成采购退货单和退货明细、退款单)
		-- 根据单据状态判断是否可以审核通过
		IF ISNULL(new.inTime) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '没有完成进仓，不能审核', MYSQL_ERRNO = 1001;
		ELSEIF new.isSubmit <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '仓库没有签收，不能审核', MYSQL_ERRNO = 1001;
		ELSEIF ISNULL(new.checkUserId) OR new.checkUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '通过审核时，最新修改员工必须与审核员工相同！', MYSQL_ERRNO = 1001;
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '通过审核时不能变更客户！！';
		ELSEIF old.payAccount <> new.payAccount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核通过时不能变更客户收款账号！！';
		ELSEIF new.creatorId = new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能由创建员工审核！！';
		END IF;
		-- 记录审核人，审核时间
		set new.checkEmpId = aid, new.checkEmpName = aName, new.checkTime = NOW();
		-- 记录操作
		insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'checked', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '审核通过';
	ELSEIF old.isCheck = 0 AND new.isCheck = -1 THEN -- 审核不通过
		-- 根据单据状态判断是否可以审核不通过
		IF new.checkUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核不通过时，最新修改员工必须与审核员工相同！', MYSQL_ERRNO = 1001;
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核不通过不能变更客户！！';
		ELSEIF old.payAccount <> new.payAccount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核不通过时不能变更客户收款账号！！';
		ELSEIF ISNULL(new.memo) OR new.memo = '' THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '审核不通过时，必须在备注栏指定不通过原因！！', MYSQL_ERRNO = 1001;
		ELSEIF new.creatorId = new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能由创建员工审核！！';
		END IF;
		-- 记录操作
		insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name, said)
		select new.id, 'checkedBack', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '审核不通过', CONCAT(' （原因：', IFNULL(new.memo, ' '), '）');
	ELSEIF old.isCheck = -1 AND new.isCheck = 0 THEN -- 提交待审
		IF ISNULL(new.inTime) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '没有完成进仓，不能提交待审', MYSQL_ERRNO = 1001;
		ELSEIF new.isSubmit <> 1 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '仓库没有签收，不能提交待审', MYSQL_ERRNO = 1001;
		ELSEIF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '提交待审时不能变更客户！！';
		ELSEIF old.payAccount <> new.payAccount THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '提交待审时不能变更客户收款账号！！';
		END IF;
		-- 记录操作
		insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'submitCheck', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '提交待审';
	ELSEIF old.isSubmit = 0 AND new.isSubmit = 1 THEN -- 仓库签收
		IF old.customerId <> new.customerId THEN 
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '仓库签收时不能变更客户！！';
		END IF;
		-- 记录操作
		insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'receive', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '仓库签收';
	ELSE
		IF new.erp_vendi_bil_id <> old.erp_vendi_bil_id THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '已指定销售单，不能修改！！';
		ELSEIF old.costUserId > 0 OR new.costUserId > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售退货单已退款给用户，不能修改！！';
		ELSEIF old.priceSumSell <> new.priceSumSell THEN
			-- 获取对应销售单总售价
			IF EXISTS(SELECT 1 FROM erp_vendi_bil a WHERE a.id = new.erp_vendi_bil_id AND a.priceSumSell < new.priceSumSell) THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '修改销售退货单时，退款总价不能大于销售单总价！！';
			END IF;
		END IF;
		-- 更改地址
		IF new.erc$telgeo_contact_id > 0 and 
			(isnull(old.erc$telgeo_contact_id) or new.erc$telgeo_contact_id <> old.erc$telgeo_contact_id)THEN
			SET new.takeGeoTel = (SELECT CONCAT('联系人:', IFNULL(a.person, ''), '  联系号码:', IFNULL(a.callnum, '')
				, '  地址:', IFNULL(a.addrroad, ''))
				FROM autopart01_crm.erc_customer_address a WHERE a.id = new.erc$telgeo_contact_id
			);
		END IF;
		-- 记录修改操作
		insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, '修改销售退货主表';
	END IF;

	set new.lastModifiedDate = CURRENT_TIMESTAMP();

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_AFTER_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_AFTER_UPDATE` AFTER UPDATE ON `erp_vendi_back` FOR EACH ROW BEGIN

-- 		IF old.isCheck = 0 AND new.isCheck = 1 THEN
			-- 生成采购退货单和退货明细
-- 		END IF;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_BEFORE_DELETE` BEFORE DELETE ON `erp_vendi_back` FOR EACH ROW BEGIN
	IF old.costTime > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售退货单已退款，不能删除！';
	ELSEIF old.isCheck > -1 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售退货单已提交待审或审核通过，不能删除！';
	ELSEIF old.inTime > 0 THEN 
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售退货单已进仓完毕，不能删除！';
	ELSEIF old.isSubmit > 0 THEN 
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售退货单已进入进仓流程，不能删除！';
	END IF;
	delete a from erp_vendi_back_bilwfw a where a.billId = old.id;
	delete a from erp_vendi_back_detail a where a.erp_vendi_back_id = old.id;
END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	销售退回明细表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_vendi_back_detail;
CREATE TABLE `erp_vendi_back_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_vendi_back_id` bigint(20) NOT NULL COMMENT '销售退货单主表ID',
  `erp_sales_detail_id` bigint(20) DEFAULT NULL COMMENT '销售明细ID',
  `erp_purch_bil_id` bigint(20) DEFAULT NULL COMMENT '采购订单ID 冗余',
  `ers_packageAttr_id` bigint(20) DEFAULT NULL COMMENT '商品的包装ID  最低一级的包裹名称即单品的计量单位',
  `goodsId` bigint(20) DEFAULT NULL COMMENT '配件 冗余字段 = ers_packageattr.goodsId',
  `supplierId` bigint(20) DEFAULT NULL COMMENT '供应商',
  `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新修改人编码',
  `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID',
  `packageQty` int(11) DEFAULT '0' COMMENT '包装数量',
  `qty` int(11) DEFAULT '0' COMMENT '实际单品数量 最低一级包装直接等于packageQty',
  `packageUnit` varchar(30) DEFAULT NULL COMMENT '包裹单位 冗余字段，触发器取ers_packageattr.packageUnit',
  `packagePrice` decimal(20,4) DEFAULT '0.0000' COMMENT '包装进货单价 ers_packageattr.newPrice',
  `price` decimal(20,4) DEFAULT NULL COMMENT '实际单品进价 最低一级包装直接等于packagePrice',
  `salesPackagePrice` decimal(20,4) DEFAULT '0.0000' COMMENT '包装售价 前台初始化取 ers_packageattr.newSalesPrice',
  `salesPrice` decimal(20,4) DEFAULT NULL COMMENT '单品售价',
  `amt` decimal(20,4) DEFAULT NULL COMMENT '总进价金额',
  `salesAmt` decimal(20,4) DEFAULT NULL COMMENT '销售金额 = packageQty * salesPackagePrice',
  `createdDate` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '初建时间；--@CreatedDate',
  `inTime` datetime DEFAULT NULL COMMENT '进仓时间，非空表示该明细进仓完毕',
  `lastModifiedDate` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最新修改时间；--@LastModifiedDate',
  `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新修改员工姓名',
  `lastModifiedBy` varchar(100) DEFAULT NULL COMMENT '最新修改人员；--@LastModifiedBy',
  `erc$telgeo_contact_id` bigint(20) DEFAULT NULL COMMENT '提货地址，从erp_salesDetail表获得',
  `takeGeoTel` varchar(1000) DEFAULT NULL COMMENT '提货地址和电话；--这里用文本不用ID，防止本单据流程中地址被修改了',
  `reason` varchar(255) DEFAULT NULL COMMENT '客户退货原因',
  `memo` varchar(255) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  UNIQUE KEY `erp_vendi_back_detail_erp_vendi_back_id_idx` (`erp_vendi_back_id`,`goodsId`) USING BTREE,
  KEY `erp_vendi_back_detail_goodsIdSupplierId_idx` (`goodsId`,`supplierId`),
  KEY `erp_vendi_back_detail_erp_sales_detail_id_idx` (`erp_sales_detail_id`),
  KEY `erp_vendi_back_detail_erp_purch_bil_id_idx` (`erp_purch_bil_id`),
  KEY `erp_vendi_back_detail_supplierId_idx` (`supplierId`),
  KEY `erp_vendi_back_detail_ers_packageAttr_id_idx` (`ers_packageAttr_id`,`erp_vendi_back_id`) USING BTREE,
  CONSTRAINT `fk_erp_vendi_back_detail_erp_goods_id` FOREIGN KEY (`goodsId`) 
		REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT `fk_erp_vendi_back_detail_erp_vendi_back_id` FOREIGN KEY (`erp_vendi_back_id`) 
		REFERENCES `erp_vendi_back` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
  CONSTRAINT `fk_erp_vendi_back_detail_ers_packageAttr_id` FOREIGN KEY (`ers_packageAttr_id`) 
		REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='销售退货单明细'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_detail_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_detail_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_back_detail` FOR EACH ROW BEGIN
	DECLARE msg, aTakeGeoTel varchar(1000);
	DECLARE aid, aGoodsId, aSupplierId, aTelgeo_contact_id, aVendiId, bVendiId, bGoodsId BIGINT;
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE aPackageQty, aQty, bQty, aDegree int;
	DECLARE aPackagePrice, aPrice, aSPackagePrice, aSPrice DECIMAL(20,4);
	DECLARE aPackageUnit varchar(100);
	DECLARE aSubmit, aCheck TINYINT;
	DECLARE iTime, cTime datetime;
	
	set msg = concat('追加销售退货单（编号：', new.erp_vendi_back_id, ', ）明细');
	-- 获取销售退货单主表信息
	SELECT a.isCheck, a.isSubmit, a.inTime, a.costTime, a.erp_vendi_bil_id
	INTO aCheck, aSubmit, iTime, cTime, aVendiId
	FROM erp_vendi_back a WHERE a.id = new.erp_vendi_back_id;

	if cTime > 0 THEN
		set msg = concat(msg, '已退款，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		set msg = concat(msg, '已进入提交待审或审核通过，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif iTime > 0 THEN
		set msg = concat(msg, '已进仓，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aSubmit > 0 THEN 
		set msg = concat(msg, '已进入进仓流程，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF ISNULL(new.reason) OR new.reason = '' THEN
		set msg = concat(msg, '必须指定配件退货原因！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 获取销售明细配件等相关信息
	SELECT a.goodsId, a.supplierId, a.packageQty, a.qty, a.packageUnit,
				a.packagePrice, a.price, a.salesPackagePrice, a.salesPrice, 
				a.erc$telgeo_contact_id, a.takeGeoTel, a.erp_vendi_bil_id
	INTO aGoodsId, aSupplierId, aPackageQty, aQty, aPackageUnit,
			aPackagePrice, aPrice, aSPackagePrice, aSPrice,
			aTelgeo_contact_id, aTakeGeoTel, bVendiId
	FROM erp_sales_detail a WHERE a.id = new.erp_sales_detail_id;
	-- 获取包装属性表信息
	SELECT a.actualQty, a.goodsId
	INTO bQty, bGoodsId
	FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;

	IF ISNULL(aVendiId) OR ISNULL(bVendiId) OR aVendiId <> bVendiId THEN
		set msg = concat(msg, '选择的销售明细与销售退货单选择的销售单不对应，不能追加配件！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aGoodsId <> bGoodsId THEN
		SET msg = concat(msg, '必须指定有效的包装！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF isnull(new.ers_packageAttr_id) OR new.ers_packageAttr_id = 0 THEN
		SET msg = concat(msg, '必须指定有效的包装！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF new.packageQty < 1 OR isnull(new.packageQty) THEN
		SET msg = concat(msg, '必须指定有效的数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF isnull(new.lastModifiedId) OR new.lastModifiedId = 0 THEN
		SET msg = concat(msg, '必须指定有效的创建人！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 最后修改用户变更
	call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
	set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	-- 设置相关信息
	SET new.goodsId = aGoodsId, new.supplierId = aSupplierId, new.createdDate = NOW(), new.lastModifiedDate  = NOW();
	SET new.packagePrice = aPrice * bQty, new.price = aPrice, new.amt = new.packagePrice * new.packageQty, 
			new.salesPackagePrice = aSPrice * bQty, new.salesPrice = aSPrice, new.salesAmt = new.salesPackagePrice * new.packageQty;
	SET new.erc$telgeo_contact_id = aTelgeo_contact_id, new.takeGeoTel = aTakeGeoTel, 
			new.qty = bQty * new.packageQty, new.packageUnit = aPackageUnit;

	IF new.qty > aQty THEN
		SET msg = concat(msg, '配件退货数量不能大于销售数量！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 更新主表总价钱
	UPDATE erp_vendi_back a 
	SET a.priceSumCome = a.priceSumCome + new.amt, a.priceSumSell = a.priceSumSell + new.salesAmt 
	WHERE a.id = new.erp_vendi_back_id;

	-- 生成提货地址
	if new.erc$telgeo_contact_id > 0 and isnull(new.takeGeoTel) then
		set new.takeGeoTel = (select CONCAT('联系人:', IFNULL(a.person, ''), '  联系号码:', IFNULL(a.callnum, ''), '  地址:', IFNULL(a.addrroad, ''))
				from autopart01_crm.erc_supplier_address a where a.id = new.erc$telgeo_contact_id
		);
	end if;

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_detail_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_detail_AFTER_INSERT` AFTER INSERT ON `erp_vendi_back_detail` FOR EACH ROW BEGIN
	-- 插入流程表
	insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.erp_vendi_back_id, 'append', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName, new.lastModifiedBy
				, CONCAT('追加销售退货明细（编号：',new.id,'），配件编号：', new.goodsId, '。');
end;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_detail_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_back_detail` FOR EACH ROW BEGIN
	DECLARE msg, aTakeGeoTel varchar(1000);
	DECLARE aid, aGoodsId, asupplierId, aTelgeo_contact_id BIGINT;
	DECLARE aName, aUserName VARCHAR(100);
	DECLARE aPackageQty, aQty, bQty, aDegree int;
	DECLARE aPackagePrice, aPrice, aSPackagePrice, aSPrice DECIMAL(20,4);
	DECLARE aPackageUnit varchar(100);
	DECLARE aSubmit, aCheck TINYINT;
	DECLARE iTime, cTime datetime;

	set msg = concat('修改销售退货单（编号：', new.erp_vendi_back_id, ', ）明细（编号：', new.id, '）时，');

	-- 获取主表相关信息
	SELECT a.isCheck, a.isSubmit, a.inTime, a.costTime
	INTO aCheck, aSubmit, iTime, cTime
	FROM erp_vendi_back a WHERE a.id = new.erp_vendi_back_id;

	-- 已进仓完毕之后不能修改
	IF old.inTime >0 THEN
		set msg = concat(msg, '仓库已完成进仓，不能修改！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	IF new.inTime > 0 AND ISNULL(old.inTime) THEN	-- 进仓完毕
		IF aSubmit <> 1 THEN
			set msg = concat(msg, '仓库没有签收，不能进仓！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.packageQty <> old.packageQty THEN
			set msg = concat(msg, '进仓完毕时，不能修改数量！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.amt <> old.amt THEN
			set msg = concat(msg, '进仓完毕时，不能修改进货价钱！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.salesAmt <> old.salesAmt THEN
			set msg = concat(msg, '进仓完毕时，不能修改进货价钱！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		END IF;
		-- 记录操作记录
		insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.erp_vendi_back_id, 'in', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
					, new.lastModifiedBy, CONCAT('销售退货明细（编号：', new.id, '）进仓完毕！');
	ELSE
		-- 修改关键信息
		IF new.erp_sales_detail_id <> old.erp_sales_detail_id THEN -- 更换销售明细，请删除再更换
			set msg = concat(msg, '已指定退货配件，不能修改配件，请删除再添加！');
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
		ELSEIF new.ers_packageAttr_id <> old.ers_packageAttr_id THEN -- 更换包装
			-- 获取对应销售明细信息
			SELECT a.qty INTO aQty FROM erp_sales_detail a WHERE a.id = new.erp_sales_detail_id;
			-- 获取单包装实际单品数量
			SELECT a.actualQty, a.packageUnit, a.goodsId 
			INTO bQty, aPackageUnit, aGoodsId 
			FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;
			-- 更新单品数量、进货包装单价、进货总价、销售包装单价、销售总价
			SET new.qty = bQty * new.packageQty
				, new.packagePrice = new.price * bQty, new.amt = new.packagePrice * new.packageQty
				, new.salesPackagePrice = new.salesPrice * bQty, new.salesAmt = new.salesPackagePrice * new.packageQty;
			-- 判断单品数量是否超过销售明细单品数量
			IF new.goodsId <> aGoodsId THEN
				SET msg = concat(msg, '请指定有效包装单位！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF new.qty > aQty THEN
				SET msg = concat(msg, '配件退货数量不能大于销售数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			END IF;
		ELSEIF new.packageQty <> old.packageQty THEN
			-- 获取对应销售明细信息
			SELECT a.qty INTO aQty FROM erp_sales_detail a WHERE a.id = new.erp_sales_detail_id;
			-- 获取单包装实际单品数量
			SELECT a.actualQty INTO bQty FROM ers_packageattr a WHERE a.id = new.ers_packageAttr_id;
			-- 更新单品数量、进货总价、销售总价
			SET new.qty = bQty * new.packageQty, new.amt = new.packagePrice * new.packageQty
				, new.salesAmt = new.salesPackagePrice * new.packageQty;
			-- 判断单品数量是否超过销售明细单品数量
			IF new.qty > aQty THEN
				SET msg = concat(msg, '配件退货数量不能大于销售数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			END IF;
		END IF;

		IF new.qty <> old.qty OR new.amt <> old.amt OR new.salesAmt <> old.salesAmt OR new.reason <> old.reason
			OR new.memo <> old.memo OR new.takeGeoTel <> old.takeGeoTel THEN
			-- 根据状态判断是否能修改
			IF cTime > 0 THEN
				set msg = concat(msg, '已退款，不能修改！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF aCheck > -1 THEN
				set msg = concat(msg, '已进入提交待审或审核通过，不能修改！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			elseif iTime > 0 THEN
				set msg = concat(msg, '已进仓，不能修改！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF aSubmit > 0 THEN 
				set msg = concat(msg, '已进入进仓流程，不能修改！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF new.packageQty < 1 OR isnull(new.packageQty) THEN
				SET msg = concat(msg, '必须指定有效的数量！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			ELSEIF isnull(new.lastModifiedId) or new.lastModifiedId = 0 THEN
				SET msg = concat(msg, '必须指定有效的修改员工！');
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
			END IF;
		END IF;
	END IF;

	-- 最后修改用户变更，获取相关信息
	IF new.lastModifiedId <> old.lastModifiedId THEN
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName, new.lastModifiedBy = aUserName;
	END IF;

	-- 更新主表总价钱
	UPDATE erp_vendi_back a 
	SET a.priceSumCome = a.priceSumCome + new.amt - old.amt, a.priceSumSell = a.priceSumSell + new.salesAmt - old.salesAmt
	WHERE a.id = new.erp_vendi_back_id;

	-- 记录操作记录
	insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select new.erp_vendi_back_id, 'selfupdated', new.lastModifiedId, new.lastModifiedEmpId, new.lastModifiedEmpName
				, new.lastModifiedBy, '自行修改销售退货单明细';

	SET new.lastModifiedDate = NOW();
end;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_detail_BEFORE_DELETE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_detail_BEFORE_DELETE` BEFORE DELETE ON `erp_vendi_back_detail` FOR EACH ROW BEGIN
	DECLARE aSubmit, aCheck TINYINT;
	DECLARE iTime, cTime datetime;
	DECLARE msg VARCHAR(1000);

	set msg = concat('销售退货单（编号：', old.erp_vendi_back_id, ', ）明细');
	SELECT a.isCheck, a.isSubmit, a.inTime , a.costTime
	INTO aCheck, aSubmit, iTime, cTime
	FROM erp_vendi_back a WHERE a.id = old.erp_vendi_back_id;
	-- 根据主表状态判断是否能删除
	IF cTime > 0 THEN
		set msg = concat(msg, '已退款，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aCheck > -1 THEN
		set msg = concat(msg, '已进入提交待审或审核通过，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	elseif iTime > 0 THEN
		set msg = concat(msg, '已进仓，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	ELSEIF aSubmit > 0 THEN 
		set msg = concat(msg, '已进入进仓流程，不能删除！');
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = msg;
	END IF;

	-- 更新主表总价钱
	UPDATE erp_vendi_back a 
	SET a.priceSumCome = a.priceSumCome - old.amt, a.priceSumSell = a.priceSumSell - old.salesAmt
	WHERE a.id = old.erp_vendi_back_id;

	-- 记录操作记录
	insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
	select old.erp_vendi_back_id, 'deleteDetail', old.lastModifiedId, old.lastModifiedEmpId, old.lastModifiedEmpName
				, old.lastModifiedBy, CONCAT('删除销售退货明细（编号：', old.id, '，销售退货单编号：', old.erp_vendi_back_id
				, '，销售明细编号：', old.erp_sales_detail_id,'，配件编号：', old.goodsId, '）');

END;;
DELIMITER ;

-- 	--------------------------------------------------------------------------------------------------------------------
-- 	销售退回状态表
-- 	--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS erp_vendi_back_bilwfw;
CREATE TABLE `erp_vendi_back_bilwfw` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `billId` bigint(20) DEFAULT NULL COMMENT '单码',
  `billStatus` varchar(50) NOT NULL COMMENT '单状态',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
  `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `userName` varchar(100) DEFAULT NULL COMMENT '登陆用户名',
  `name` varchar(255) NOT NULL COMMENT '步骤名称',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `said` varchar(255) DEFAULT NULL COMMENT '步骤附言',
  `memo` varchar(255) DEFAULT NULL COMMENT '其他关联',
  PRIMARY KEY (`id`),
  KEY `userId_idx` (`userId`),
  KEY `billStatus_idx` (`billStatus`),
  KEY `opTime_idx` (`opTime`),
  KEY `erp_vendi_back_bilwfw_billId_idx` (`billId`),
  CONSTRAINT `fk_erp_vendi_back_bilwfw_billId` FOREIGN KEY (`billId`) REFERENCES `erp_vendi_back` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='销售退货状态表'
;

-- 	--------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_vendi_back_bilwfw_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_back_bilwfw` FOR EACH ROW BEGIN
	set new.opTime = now()
		,new.memo = concat('员工（编号：', IFNULL(new.empId, ' '), ' 姓名：', IFNULL(new.empName, ' ')
		, ' 用户编号：', IFNULL(new.userId, ' '), '）销售退货单（编号：', new.billId,'）', new.name, IFNULL(new.said,' '));
END;;
DELIMITER ;