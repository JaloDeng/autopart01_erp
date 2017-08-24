
set FOREIGN_key_checks = 0;

-- ----------------------------
-- Table structure for erp_inquiry_bil
-- ----------------------------
-- 创建一条记录时，必须填写 creatorId 即客服，写入后不可变更
-- 第一次报价时，必须填写 updaterId 即跟单，写入后不可变更
-- 本表及其子表的数据，只有这两人可以操作
DROP TABLE IF EXISTS `erp_inquiry_bil`;
CREATE TABLE `erp_inquiry_bil` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `customerId` bigint(20) NOT NULL COMMENT '客户  必填项目',
	isSubmit TINYINT DEFAULT 0 COMMENT '单据由客服还是跟单操作。1：跟单 0：客服',
  `creatorId` bigint(20) NOT NULL COMMENT '初建人编码；--@CreatorId 公司的客服 sec$user_id',
	empId bigint(20) DEFAULT null COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
  `updaterId` bigint(20) DEFAULT NULL COMMENT '报价人编码；--@UpdaterId  自己的跟单 ',
	updateEmpId bigint(20) DEFAULT NULL COMMENT '报价人员工ID；--@UpdaterId  自己的跟单 erc$staff_id',
  `priceSumCome` decimal(20,4) DEFAULT NULL COMMENT '进价金额总计',
  `priceSumSell` decimal(20,4) DEFAULT NULL COMMENT '售价金额总计',
  `priceSumShip` decimal(20,4) DEFAULT NULL COMMENT '运费金额总计',
	zoneNum  VARCHAR(30) null DEFAULT NULL COMMENT '客户所在地区的区号 触发器获取',
  `code` varchar(100) DEFAULT NULL COMMENT '询价单号  新增记录时由触发器生成',
  `quoteCode` varchar(100) DEFAULT NULL COMMENT '报价单号  updaterId值由空变非空时由触发器生成，写入后不可变更',
	empName varchar(100) DEFAULT null COMMENT '员工姓名 客服',
	updateEmpName varchar(100) DEFAULT null COMMENT '报价人姓名 跟单',
  `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
  `createdBy` varchar(100) DEFAULT NULL COMMENT '登录账户名称  初建人名称；--@CreatedBy',
  `lastModifiedDate` datetime DEFAULT NULL COMMENT '最新修改时间；--@LastModifiedDate',
	lastModifiedId bigint(20) DEFAULT NULL COMMENT '最新修改人编码；正常是审核人 触发器维护 --',
	lastModifiedEmpId bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
	lastModifiedEmpName varchar(100) DEFAULT null COMMENT '最新修改员工姓名',
  `lastModifiedBy` varchar(100) DEFAULT NULL COMMENT '最新修改人员；--@LastModifiedBy',
  `needTime` datetime DEFAULT NULL COMMENT '期限时间  客户要求什么时间到货',
	erc$telgeo_contact_id BIGINT(20) DEFAULT NULL COMMENT '公司自提，提货地址和电话_id',
--   `customerGeoTel` varchar(1000) DEFAULT NULL COMMENT '收货地址和电话；--这里用文本不用ID，防止本单据流程中地址被修改了',
  `memo` varchar(1000) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  UNIQUE KEY `erp_inquiry_bil_code_UNIQUE` (`code`),
  KEY `erp_inquiry_bil_customerId_idx` (`customerId`),
  KEY `erp_inquiry_bil_creatorId_idx` (`creatorId`),
  KEY `erp_inquiry_bil_updaterId_idx` (`updaterId`),
  KEY `erp_inquiry_bil_createdDate_idx` (`createdDate`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 
COMMENT='询价报价单主表＃--sn=TB04101&type=mdsMaster&jname=InquiryOfferBill&title=询价报价单&finds={"code":1,"createdDate":1,"lastModifiedDate":1}'
;

-- --------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `erp_inquiry_bilwfw`;
CREATE TABLE `erp_inquiry_bilwfw` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `billId` bigint(20) DEFAULT NULL COMMENT '单码  erp_inquiry_bil_id',
  `billStatus` varchar(50) NOT NULL COMMENT '单状态',
  `prevId` bigint(20) DEFAULT NULL COMMENT '前个步骤',
  `userId` bigint(20) NOT NULL COMMENT '登录用户编码',
	empId BIGINT(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `name` varchar(100) NOT NULL COMMENT '步骤名称',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `said` varchar(255) DEFAULT NULL COMMENT '步骤附言',
  `memo` varchar(255) DEFAULT NULL COMMENT '其他关联',
  PRIMARY KEY (`id`),
  KEY `erp_inquiry_bilwfw_userId_idx` (`userId`),
  KEY `erp_inquiry_bilwfw_billStatus_idx` (billId, billStatus),
  KEY `erp_inquiry_bilwfw_status_idx` (billStatus),
  KEY `erp_inquiry_bilwfw_opTime_idx` (`opTime`),
--   KEY `erp_inquiry_bilwfw_billId` (`billId`),
--   KEY `FKCtb04103fk00001qunzhi` (`prevId`),
  CONSTRAINT `fk_erp_inquiry_bilwfw_billId` FOREIGN KEY (`billId`) 
		REFERENCES `erp_inquiry_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
--   CONSTRAINT `FKCtb04103fk00001qunzhi` FOREIGN KEY (`prevId`) REFERENCES `erp_inquiry_bilwfw` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 
COMMENT='报价单流程步骤＃--sn=TB04103&type=mdsFlow&jname=InquiryOfferBillStep&title=报价单状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}'
;

-- ------------------------------------------------------------------------------
-- 询价单流程表
DROP TRIGGER IF EXISTS `tr_erpinquiry_bilwfw_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erpinquiry_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_inquiry_bilwfw` FOR EACH ROW BEGIN
	DECLARE aid BIGINT(20);
	declare aName VARCHAR(100);
	DECLARE aNeedTime datetime;
	DECLARE aErc$telgeo_contact_id bigint(20);
	if exists(select 1 from autopart01_security.sec$user a where a.id = new.userId) THEN
		if new.billStatus <> 'justcreated' and new.billStatus <> 'append' then
			select a.id, a.name into aid, aName
			from autopart01_crm.`erc$staff` a where a.userId = new.userId;
			set new.empId = aid, new.empName = aName;
			update erp_inquiry_bil a 
			set a.lastModifiedDate = CURRENT_TIMESTAMP(), a.lastModifiedId = new.userId, a.lastModifiedEmpId = aid, a.lastModifiedEmpName = aName
			where a.id = new.billId;
		end if;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增操作记录，必须指定有效的创建人！';
	end if;
	if new.billStatus = 'submitthatedit' then  -- 提交跟单
		update erp_inquiry_bil a set a.isSubmit = 1 where a.id = new.billId;
	elseif new.billStatus = 'thatreplyedit' then  -- 跟单“回复”给客服
		update erp_inquiry_bil a set a.isSubmit = 0 where a.id = new.billId;
	elseif new.billStatus = 'submitthatview' then  -- 提交待审
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'submitthatview') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已提交，不能重复提交！';
		end if;
	elseif new.billStatus = 'checked' then -- 转销售订单
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'checked') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已转销售订单，不能重复操作！';
		end if;
		select a.needTime, a.erc$telgeo_contact_id into aNeedTime, aErc$telgeo_contact_id
		from erp_inquiry_bil a where a.id = new.billId;
		if isnull(aErc$telgeo_contact_id) THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '转销售订单，必须指定发货地址！';
		end if;
		insert into erp_vendi_bil(erp_inquiry_bil_id, customerId, creatorId, createdDate, needTime, erc$telgeo_contact_id
			, createdBy) 
		select new.billId, a.customerId, new.userId, now(), aNeedTime, aErc$telgeo_contact_id
			, (select a.userName from autopart01_crm.`erc$staff` a where a.userId = new.userId)
		from erp_inquiry_bil a
		;
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能生成销售订单主表!';
		ELSE
			set aid = LAST_INSERT_ID();
		end if;
		insert into autopart01_erp.erp_vendi_bilwfw (billId, billStatus, userId, name, opTime) 
		values (aid, 'justcreated', new.`userId`, '刚刚创建', CURRENT_TIMESTAMP());
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能写入销售订单状态表!';
		end if;
	end if;
end;;
DELIMITER ;

-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_inquiry_bil_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_inquiry_bil_BEFORE_INSERT` BEFORE INSERT ON `erp_inquiry_bil` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName varchar(100);
	declare zoneNum VARCHAR(100);

	if exists(select 1 from autopart01_crm.`erc$customer` a where a.id = new.customerId limit 1) then
		set new.zoneNum = (select a.zonenum from autopart01_crm.`erc$customer` a where a.id = new.customerId);
		if isnull(new.zoneNum) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未指定客户的电话区号！',MYSQL_ERRNO = 1001;
		end if;
	else
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增询价单，必须指定有效的客户！';
	end if;
	if exists(select 1 from autopart01_security.sec$user a where a.id = new.creatorId) THEN
		if new.updaterId > 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '不能同时指定客服和跟单！';
		end if;
		select a.id, a.name into aid, aName
		from autopart01_crm.`erc$staff` a where a.userId = new.creatorId;
		set new.empId = aid, new.empName = aName;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增询价单，必须指定创建人！';
	end if;
	set new.createdDate = CURRENT_TIMESTAMP();
	-- 生成code 区号+8位日期+4位员工id+4位流水
	set new.code = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.creatorId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_inquiry_bil a 
				where date(a.createdDate) = date(new.createdDate) and a.creatorId = new.creatorId), 0
			) + 1, 4, 0)
	);
	
end;;
DELIMITER ;

-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_inquiry_bil_BEFORE_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_inquiry_bil_BEFORE_UPDATE` BEFORE UPDATE ON `erp_inquiry_bil` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName varchar(100);

	if isnull(old.updaterId) THEN
		if new.updaterId > 0 THEN
			select a.id, a.name into aid, aName
			from autopart01_crm.`erc$staff` a where a.userId = new.updaterId;
			set new.updateEmpId = aid, new.updateEmpName = aName;
			-- 生成quoteCode 区号+8位日期+4位员工id+4位流水
			set new.quoteCode = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.updaterId,4,0)
				, LPAD(
					ifnull((select max(right(a.quoteCode, 4)) from erp_inquiry_bil a 
						where date(a.createdDate) = date(new.createdDate) and a.updaterId = new.updaterId), 0
					) + 1, 4, 0)
			);
		end if;
	ELSE
		if new.updaterId > 0 and old.updaterId <> new.updaterId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '已指定跟单，不能变更！';
		end if;
	end if;
end;;
DELIMITER ;

