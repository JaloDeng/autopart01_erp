set foreign_key_checks = 0;

-- DROP TABLE IF EXISTS erp_inquiry_bil;
-- CREATE TABLE `erp_inquiry_bil` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `customerId` bigint(20) NOT NULL COMMENT '客户  必填项目',
--   `isSubmit` tinyint(4) DEFAULT '0' COMMENT '单据由客服还是跟单操作。1：跟单 0：客服',
--   `creatorId` bigint(20) NOT NULL COMMENT '初建人编码；--@CreatorId 公司的客服 sec$user_id',
--   `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
--   `updaterId` bigint(20) DEFAULT NULL COMMENT '报价人编码；--@UpdaterId  自己的跟单 ',
--   `updateEmpId` bigint(20) DEFAULT NULL COMMENT '报价人员工ID；--@UpdaterId  自己的跟单 erc$staff_id',
--   `priceSumCome` decimal(20,4) DEFAULT NULL COMMENT '进价金额总计',
--   `priceSumSell` decimal(20,4) DEFAULT NULL COMMENT '售价金额总计',
--   `priceSumShip` decimal(20,4) DEFAULT NULL COMMENT '运费金额总计',
--   `zoneNum` varchar(30) DEFAULT NULL COMMENT '客户所在地区的区号 触发器获取',
--   `code` varchar(100) DEFAULT NULL COMMENT '询价单号  新增记录时由触发器生成',
--   `quoteCode` varchar(100) DEFAULT NULL COMMENT '报价单号  updaterId值由空变非空时由触发器生成，写入后不可变更',
--   `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名 客服',
--   `updateEmpName` varchar(100) DEFAULT NULL COMMENT '报价人姓名 跟单',
--   `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
--   `createdBy` varchar(100) DEFAULT NULL COMMENT '登录账户名称  初建人名称；--@CreatedBy',
--   `lastModifiedDate` datetime DEFAULT NULL COMMENT '最新修改时间；--@LastModifiedDate',
--   `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新修改人编码；正常是审核人 触发器维护 --',
--   `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
--   `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新修改员工姓名',
--   `lastModifiedBy` varchar(100) DEFAULT NULL COMMENT '最新修改人员；--@LastModifiedBy',
--   `needTime` datetime DEFAULT NULL COMMENT '期限时间  客户要求什么时间到货',
--   `erc$telgeo_contact_id` bigint(20) DEFAULT NULL COMMENT '公司自提，提货地址和电话_id',
--   `memo` varchar(1000) DEFAULT NULL COMMENT '备注',
--   PRIMARY KEY (`id`),
--   UNIQUE KEY `erp_inquiry_bil_code_UNIQUE` (`code`),
--   KEY `erp_inquiry_bil_customerId_idx` (`customerId`),
--   KEY `erp_inquiry_bil_creatorId_idx` (`creatorId`),
--   KEY `erp_inquiry_bil_updaterId_idx` (`updaterId`),
--   KEY `erp_inquiry_bil_createdDate_idx` (`createdDate`)
-- ) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COMMENT='询价报价单主表＃--sn=TB04101&type=mdsMaster&jname=InquiryOfferBill&title=询价报价单&finds={"code":1,"createdDate":1,"lastModifiedDate":1}'
-- ;

DROP TRIGGER IF EXISTS tr_erp_inquiry_bil_BEFORE_INSERT;
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
		set new.lastModifiedDate = CURRENT_TIMESTAMP(), new.lastModifiedId = new.creatorId
			, new.lastModifiedEmpId = new.empId, new.lastModifiedEmpName = new.empName;
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

-- 			insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, name, optime)
-- 			select new.id, 'justcreated', new.creatorId, new.empId, new.empName, '刚刚创建',  CURRENT_TIMESTAMP()
-- ;
-- -- 			from erp_inquiry_bil a WHERE a.id = new.erp_inquiry_bil_id;
end;;
DELIMITER ;

DROP TRIGGER IF EXISTS tr_erp_inquiry_bil_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_inquiry_bil_AFTER_INSERT` AFTER INSERT ON `erp_inquiry_bil` FOR EACH ROW begin
		insert into erp_inquiry_bilwfw(billId, billstatus, userid, empId, empName, name, optime)
		select new.id, 'justcreated', new.creatorId, new.empId, new.empName, '刚刚创建',  CURRENT_TIMESTAMP()
;
end;;
DELIMITER ;
-- ------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_erp_inquiry_bil_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_inquiry_bil_BEFORE_UPDATE` BEFORE UPDATE ON `erp_inquiry_bil` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName varchar(100);
	
	IF old.`code` <> new.`code` THEN
		SET new.`code` = old.`code`;
	END IF;

	if isnull(old.updaterId) THEN
		if new.updaterId > 0 THEN
			select a.id, a.name into aid, aName
			from autopart01_crm.`erc$staff` a where a.userId = new.updaterId;
			set new.updateEmpId = aid, new.updateEmpName = aName;

			set new.lastModifiedDate = CURRENT_TIMESTAMP(), new.lastModifiedId = new.updaterId
			, new.lastModifiedEmpId = aid, new.lastModifiedEmpName = aName;

			-- 生成quoteCode 区号+8位日期+4位员工id+4位流水
			set new.quoteCode = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.updaterId,4,0)
				, LPAD(
					ifnull((select max(right(a.quoteCode, 4)) from erp_inquiry_bil a 
						where date(a.createdDate) = date(new.createdDate) and a.updaterId = new.updaterId), 0
					) + 1, 4, 0)
			);
		end if;
	ELSE
		if old.updaterId <> new.updaterId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '已指定跟单，不能变更！';
		end if;
	end if;
end;;
DELIMITER ;