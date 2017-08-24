set FOREIGN_key_checks = 0;

-- 销售订单主表
drop table if exists erp_vendi_bil;
CREATE TABLE `erp_vendi_bil` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_inquiry_bil_id` bigint(20) DEFAULT NULL COMMENT '来源单编码 从询价单转入的由触发器自动填入，否则为空',

-- 	canDelivery TINYINT default 0 COMMENT '该订单是否已出仓。canDelivery = 1 已出仓可发货',
  `customerId` bigint(20) NOT NULL COMMENT '客户 从询价单转入的由触发器自动填入，否则新增时用户界面选择',
  `creatorId` bigint(20) NOT NULL COMMENT '登录账户ID 初建人编码；--@CreatorId',
	empId bigint(20) DEFAULT null COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
--   `updaterId` bigint(20) DEFAULT NULL COMMENT '修改单据员工登录账户ID；--@UpdaterId  自己的跟单',
-- 	updateEmpId bigint(20) DEFAULT NULL COMMENT '报价人员工ID；--@UpdaterId  自己的跟单 erc$staff_id',
	empName varchar(100) DEFAULT null COMMENT '员工姓名。如果是询价单转，是执行checked的员工，否则是直接新增的员工',
-- 	updateEmpName varchar(100) DEFAULT null COMMENT '修改单据员工姓名 ',
	zoneNum  VARCHAR(30) null DEFAULT NULL COMMENT '客户所在地区的区号 触发器获取',
  `code` varchar(100) NOT NULL COMMENT '单号 新增时触发器生成',
  `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
  `createdBy` varchar(255) DEFAULT NULL COMMENT '登录账户名称  初建人员；--@CreatedBy',
	costTime datetime DEFAULT NULL COMMENT '交费时间',
	outTime datetime DEFAULT NULL COMMENT '出仓时间 非空时已出仓可发货',
	outUserId bigint DEFAULT NULL COMMENT '出仓人 ',
	outEmpId bigint(20) DEFAULT null COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
	outEmpName varchar(100) DEFAULT null COMMENT '员工姓名。如果是询价单转，是执行checked的员工，否则是直接新增的员工',
  `lastModifiedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
	lastModifiedId bigint(20) DEFAULT NULL COMMENT '最新修改人编码；正常是审核人 触发器维护 --',
	lastModifiedEmpId bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
	lastModifiedEmpName varchar(100) DEFAULT null COMMENT '最新修改员工姓名',
  `lastModifiedBy` varchar(255) DEFAULT NULL COMMENT '最新人员；--@LastModifiedBy',
-- 销售总金额
-- 运费
-- 上门安装服务费， 有可能拆表
  `needTime` datetime DEFAULT NULL COMMENT '期限时间  客户要求什么时间到货',
	erc$telgeo_contact_id BIGINT(20) DEFAULT NULL COMMENT '公司自提，提货地址和电话_id',
  `takeGeoTel` varchar(1000) DEFAULT NULL COMMENT '提货地址和电话；--这里用文本不用ID，防止本单据流程中地址被修改了',
  `memo` varchar(2000) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `erp_vendi_bil_erp_inquiry_bil_id_idx` (`erp_inquiry_bil_id`),
  KEY `erp_vendi_bil_creatorId_idx` (`creatorId`),
  KEY `erp_vendi_bil_lastModifiedId_idx` (`lastModifiedId`),
  KEY `erp_vendi_bil_createdDate_idx` (`createdDate`),
  CONSTRAINT `fk_erp_vendi_bil_erp_inquiry_bil_id` FOREIGN KEY (`erp_inquiry_bil_id`) 
		REFERENCES `erp_inquiry_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
COMMENT='销售订单主表＃--sn=TB04001&type=mdsMaster&jname=VenditionBill&title=销售订单&finds={"createdDate":1,"lastModifiedDate":1}'
;
-- ------------------------------------------------------------------------------
-- 销售订单流程表
drop table if exists erp_vendi_bilwfw;
CREATE TABLE `erp_vendi_bilwfw` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `billId` bigint(20) DEFAULT NULL COMMENT '单码  erp_vendi_bil_id',
  `billStatus` varchar(50) NOT NULL COMMENT '单状态',
  `prevId` bigint(20) DEFAULT NULL COMMENT '前个步骤',
  `userId` bigint(20) NOT NULL COMMENT '用户编码  登录帐号ID',
	empId BIGINT(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `name` varchar(255) NOT NULL COMMENT '步骤名称',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `said` varchar(255) DEFAULT NULL COMMENT '步骤附言',
  `memo` varchar(255) DEFAULT NULL COMMENT '其他关联',
  PRIMARY KEY (`id`),
  KEY `erp_vendi_bilwfw_userId_idx` (`userId`),
  KEY `erp_vendi_bilwfw_billStatus_idx` (billId, `billStatus`),
  KEY `erp_vendi_bilwfw_status_idx` (`billStatus`),
  KEY `erp_vendi_bilwfw_opTime_idx` (`opTime`),
--   KEY `erp_vendi_bilwfw_billId` (`billId`),
--   KEY `erp_vendi_bilwfw_prevId_idx` (`prevId`),
  CONSTRAINT `fk_erp_vendi_bilwfw_billId` FOREIGN KEY (`billId`) 
		REFERENCES `erp_purch_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
-- ,  CONSTRAINT `FKCtb03003fk00001qunzhi` FOREIGN KEY (`prevId`) REFERENCES `erp_vendi_bilwfw` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
COMMENT='销售订单流程步骤＃--sn=TB03003&type=mdsFlow&jname=PurchaseBillStep&title=采购单状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}'
;
-- ------------------------------------------------------------------------------
-- 销售订单主表
DROP TRIGGER IF EXISTS `tr_erp_vendi_bil_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_bil` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName varchar(100);
	if exists(select 1 from autopart01_crm.`crm$customer` a where a.id = new.customerId limit 1) then
		set new.zoneNum = (select a.zonenum from autopart01_crm.`erc$customer` a where a.id = new.customerId);
		if isnull(new.zoneNum) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未指定客户的电话区号！',MYSQL_ERRNO = 1001;
		end if;
	else
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售单，必须指定有效的客户！';
	end if;
	if exists(select 1 from autopart01_crm.`erc$staff` a where a.userId = new.creatorId) THEN
		select a.id, a.name into aid, aName
		from autopart01_crm.`erc$staff` a where a.userId = new.creatorId;
		set new.empId = aid, new.empName = aName;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售单，必须指定创建人！';
	end if;
	if new.erc$telgeo_contact_id > 0 THEN
		if exists(select 1 from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id) then
			set new.takeGeoTel = (select concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
				from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id
			);
		ELSE
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售单时，提货地址和电话无效！';
		end if;
	end if;
	-- 生成code 区号+8位日期+4位员工id+4位流水
	set new.code = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.creatorId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_vendi_bil a 
				where date(a.createdDate) = date(new.createdDate) and a.creatorId = new.creatorId), 0
			) + 1, 4, 0)
	);
	-- 生成发货地址文本
	if new.erc$telgeo_contact_id > 0 THEN
		set new.takeGeoTel = (select concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
			from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id
		);
	end if;
end;;
DELIMITER ;
-- ------------------------------------------------------------------------------

DROP TRIGGER IF EXISTS `tr_erp_vendi_bil_before_update`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_before_update` BEFORE update ON autopart01_erp.erp_vendi_bil FOR EACH ROW BEGIN
	if exists(select 1 from erp_vendi_bilwfw a where a.billId = new.id and a.billStatus = 'submitthatview') THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '订单已提交审核，不能修改！';
	elseif exists(select 1 from erp_vendi_bilwfw a where a.billId = new.id and a.billStatus = 'checked') THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '订单已审核通过，不能修改！';
	else
		insert into erp_vendi_bilwfw(billId, billStatus, userId, name, opTime) 
		values (new.id, 'selfupdated', new.lastModifiedId, '自行修改', CURRENT_TIMESTAMP());
	end if;
end;;
DELIMITER ;
-- ------------------------------------------------------------------------------
-- 销售订单流程表
DROP TRIGGER IF EXISTS `tr_erp_vendi_bilwfw_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_bilwfw` FOR EACH ROW begin
	declare aid bigint(20);
	declare aName VARCHAR(100);
	if exists(select 1 from autopart01_crm.`erc$staff` a where a.userId = new.userId) THEN
		select a.id, a.name into aid, aName
		from autopart01_crm.`erc$staff` a where a.userId = new.userId;
		set new.empId = aid, new.empName = aName;
		update erp_vendi_bil a 
		set a.lastModifiedId = new.userId, a.lastModifiedEmpId = aid, a.lastModifiedEmpName = aName
		where a.id = new.billId;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增操作记录，必须指定操作人员！';
	end if;

	if new.billStatus = 'submitthatview' then  -- 提交待审
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'submitthatview') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已提交，不能重复提交！';
		end if;
	elseif new.billStatus = 'checked' then -- 转销售订单
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'checked') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已转销售订单，不能重复操作！';
		end if;
		if exists(
				select 1 
				from erp_vendi_bil a 
					INNER JOIN erp_vendi_detail b on a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
					INNER JOIN erp_goods g on b.goodsId = g.goodsId
				where a.id = new.billId and b.isBuy = 1 and g.dynamicQty < b.amount  limit 1
			) THEN  -- 库存不足， 生成采购订单
			-- 生成采购订单主表
			insert into erp_purch_bil( erp_inquiry_bil_id, supplierId, creatorId, createdDate
				, createdBy
				, memo)
			select DISTINCT a.erp_inquiry_bil_id, a.supplierId, new.userId, CURRENT_TIMESTAMP()
				, (select a.userName from autopart01_crm.`erc$staff` a where a.userId = new.userId)
				, concat('销售订单审核库存不足自动转入。')
			from erp_vendi_bil a 
			where a.id = new.billId ;
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能生成采购订单主表!';
			end if;

			update erp_vendi_bil a 
					INNER JOIN erp_vendi_detail b on a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
					INNER JOIN erp_goodsBook g on b.goodsId = g.goodsId
			set b.isEnough = 0
			where a.id = new.billId and b.isBuy = 1 and g.dynamicQty < b.amount
			;
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功修改是否可以出仓标志!';
			end if;
		else	-- 库存足够， 修改状态为可以出库
			update  erp_vendi_bil a 
				INNER JOIN erp_vendi_detail b on a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
			set b.isEnough = 1 
			where b.isBuy = 1 and a.id = new.billId;
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功修改是否可以出仓标志!';
			end if;
		end if;
	elseif new.billStatus = 'flowaway' then -- 出仓完成, 修改出仓时间表示已完成出仓
		update erp_vendi_bil a 
		set a.outTime = CURRENT_TIME()
			, a.outUserId = new.userId, a.outEmpId = aid, a.outEmpName = aName
		where a.id = new.billId;
		-- 生成货运信息表
		insert into erp_vendi_deliv(erp_vendi_bil_id, userId, empId, empName, opTime)
		select new.billId, new.userId, new.empId, new.empName, CURRENT_TIMESTAMP()
		;
-- 	elseif new.billStatus = 'flowaway' then -- 出仓完成, 修改
	end if;
end;;
DELIMITER ;

-- 货运信息表
drop table if exists erp_vendi_deliv;
CREATE TABLE `erp_vendi_deliv` (
  `erp_vendi_bil_id` bigint(20) NOT NULL COMMENT '销售订单ID',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
	empId BIGINT(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
	delivTime datetime NULL COMMENT  '发货时间。非空表示已发货',
	endTime datetime NULL COMMENT  '签收时间。非空表示客户已签收',
  `opTime` datetime NOT NULL COMMENT  '日期时间；--@CreatedDate',
  `delivNo` varchar(100) DEFAULT NULL COMMENT '货运单号 非空为已发货',
  `memo` varchar(255) DEFAULT NULL COMMENT '货物中途信息',
  PRIMARY KEY (`erp_vendi_bil_id`),
  KEY `userId_idx` (`userId`),
  KEY `opTime_idx` (`opTime`),
  CONSTRAINT `fk_erp_vendi_deliv_erp_vendi_bil_id` FOREIGN KEY (`erp_vendi_bil_id`) 
		REFERENCES `erp_vendi_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
COMMENT='销售发货物流流程步骤＃--sn=TB04007&type=mdsFlow&jname=VenditionDeliverBillStep&title=销售发货物流状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}'
;

DROP TRIGGER IF EXISTS `tr_erp_vendi_deliv_before_update`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_deliv_before_update` BEFORE update ON autopart01_erp.erp_vendi_deliv FOR EACH ROW BEGIN
	if new.delivNo > '' and isnull(old.delivNo) THEN
		set new.delivTime = CURRENT_TIMESTAMP();
	end if;
end;;
DELIMITER ;