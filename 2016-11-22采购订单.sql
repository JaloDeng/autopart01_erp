set FOREIGN_key_checks = 0;

-- 采购订单主表
drop table if exists erp_purch_bil;
CREATE TABLE `erp_purch_bil` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_inquiry_bil_id` bigint(20) DEFAULT NULL COMMENT '询价单ID。为空表示是公司直接采购',

  `supplierId` bigint(20) NOT NULL COMMENT '供应商',
  `creatorId` bigint(20) NOT NULL COMMENT '初建人编码；--@CreatorId',
	empId bigint(20) DEFAULT null COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
	empName varchar(100) DEFAULT null COMMENT '员工姓名。如果是询价单转，是执行checked的员工，否则是直接新增的员工',
	zoneNum  VARCHAR(30) null DEFAULT NULL COMMENT '客户所在地区的区号 触发器获取',
  `code` varchar(100) NOT NULL COMMENT '单号 新增时触发器生成',
  `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
  `createdBy` varchar(100) DEFAULT NULL COMMENT '初建人员；--@CreatedBy 登录用户名',
	costTime datetime DEFAULT NULL COMMENT '付款时间  为空的数据即为汇款申请的数据',
	inTime datetime DEFAULT NULL COMMENT '进仓时间 非空时已出仓可发货',
	inUserId bigint DEFAULT NULL COMMENT '进人 ',
	inEmpId bigint(20) DEFAULT null COMMENT '出仓员工ID；--@  erc$staff_id',
	inEmpName varchar(100) DEFAULT null COMMENT '员工姓名。是执行checked的员工',
  `lastModifiedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
	lastModifiedId bigint(20) DEFAULT NULL COMMENT '最新修改人编码；正常是审核人 触发器维护 --',
	lastModifiedEmpId bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
	lastModifiedEmpName varchar(100) DEFAULT null COMMENT '最新修改员工姓名',
  `lastModifiedBy` varchar(255) DEFAULT NULL COMMENT '最新人员；--@LastModifiedBy',
  `priceSumCome` decimal(20,4) DEFAULT NULL COMMENT '进价金额总计',
  `priceSumShip` decimal(20,4) DEFAULT NULL COMMENT '运费金额总计',
  `needTime` datetime DEFAULT NULL COMMENT '期限时间  客户要求什么时间到货',
	erc$telgeo_contact_id BIGINT(20) DEFAULT NULL COMMENT '公司自提，提货地址和电话_id',
  `takeGeoTel` varchar(1000) DEFAULT NULL COMMENT '提货地址和电话；--这里用文本不用ID，防止本单据流程中地址被修改了',
  `memo` varchar(2000) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  UNIQUE KEY `code_UNIQUE` (`code`),
  KEY `creatorId_idx` (`creatorId`),
  KEY `createdDate_idx` (`createdDate`),
  KEY `erp_inquiry_bil_id_idx` (`erp_inquiry_bil_id`),
  CONSTRAINT `fk_erp_purch_bil_erp_inquiry_bil_id` FOREIGN KEY (`erp_inquiry_bil_id`) 
	REFERENCES `erp_inquiry_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
COMMENT='采购单主表＃--sn=TB03001&type=mdsMaster&jname=PurchaseBill&title=采购单&finds={"code":1,"createdDate":1}'
;

-- ------------------------------------------------------------------------------
drop table if exists erp_purch_bilwfw;
CREATE TABLE `erp_purch_bilwfw` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `billId` bigint(20) DEFAULT NULL COMMENT '单码',
  `billStatus` varchar(50) NOT NULL COMMENT '单状态',
  `prevId` bigint(20) DEFAULT NULL COMMENT '前个步骤',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
	empId BIGINT(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `name` varchar(255) NOT NULL COMMENT '步骤名称',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `said` varchar(255) DEFAULT NULL COMMENT '步骤附言',
  `memo` varchar(255) DEFAULT NULL COMMENT '其他关联',
  PRIMARY KEY (`id`),
  KEY `userId_idx` (`userId`),
  KEY `billStatus_idx` (`billStatus`),
  KEY `opTime_idx` (`opTime`),
  KEY `FKCtb03003fk00000qunzhi` (`billId`),
  KEY `FKCtb03003fk00001qunzhi` (`prevId`),
  CONSTRAINT `fk_erp_purch_bilwfw_billId` FOREIGN KEY (`billId`) REFERENCES `erp_purch_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
-- ,  CONSTRAINT `FKCtb03003fk00001qunzhi` FOREIGN KEY (`prevId`) REFERENCES `erp_purch_bilwfw` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购单流程步骤＃--sn=TB03003&type=mdsFlow&jname=PurchaseBillStep&title=采购单状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}';


-- ------------------------------------------------------------------------------
drop table if exists erp_purch_detail;
CREATE TABLE `erp_purch_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
	erp_purch_bil_id bigint(20) not null COMMENT '采购订单主表ID',
  `goodsId` bigint(20) NOT NULL COMMENT '配件',
--   `supplierId` bigint(20) DEFAULT NULL COMMENT '供应商 暂时不需要',
  `qty` decimal(20,4) NOT NULL COMMENT '数量',
  `unit` varchar(255) NOT NULL COMMENT '单位',
--   `packs` decimal(20,4) DEFAULT NULL COMMENT '件数 暂时不需要',
--   `packsUnit` varchar(255) DEFAULT NULL COMMENT '包装 暂时不需要',
  `price` decimal(20,4) DEFAULT NULL COMMENT '进价',
  `amt` decimal(20,4) DEFAULT NULL COMMENT '进价金额',
--   `priceTune` decimal(20,4) DEFAULT NULL COMMENT '分摊金额',
  `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
  `updatedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
  `memo` varchar(255) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `goodsId_idx` (`goodsId`),
--   KEY `supplierId_idx` (`supplierId`),
  KEY `createdDate_idx` (`createdDate`)
	, CONSTRAINT `fk_erp_purch_detail_erp_purch_bil_id` FOREIGN KEY (`erp_purch_bil_id`) 
		REFERENCES erp_purch_bil(`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
COMMENT='采购单明细＃--sn=TB03002&type=mdsDetail&jname=PurchaseDetail&title=&finds={"itemId":1,"createdDate":1}';

-- ------------------------------------------------------------------------------
-- 采购订单主表
DROP TRIGGER IF EXISTS `tr_erp_purch_bil_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_bil` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName varchar(100);
	if exists(select 1 from autopart01_crm.`erc$supplier` a where a.id = new.supplierId limit 1) then
		set new.zoneNum = (select a.zonenum from autopart01_crm.`erc$supplier` a where a.id = new.supplierId);
		if isnull(new.zoneNum) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未指定客户的电话区号！',MYSQL_ERRNO = 1001;
		end if;
	else
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增采购单，必须指定有效的客户！';
	end if;
	if exists(select 1 from autopart01_security.sec$staff a where a.userId = new.creatorId) THEN
		select a.id, a.name into aid, aName
		from autopart01_crm.`erc$staff` a where a.userId = new.creatorId;
		set new.empId = aid, new.empName = aName;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增采购单，必须指定创建人！';
	end if;
	if new.erc$telgeo_contact_id > 0 THEN
		if exists(select 1 from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id) then
			set new.takeGeoTel = (select concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
				from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id
			);
		ELSE
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增采购单时，发货地址和电话无效！';
		end if;
	end if;
	-- 生成code 区号+8位日期+4位员工id+4位流水
	set new.code = concat(new.zoneNum, date_format(new.createdDate,'%Y%m%d'), LPAD(new.creatorId,4,0)
		, LPAD(
			ifnull((select max(right(a.code, 4)) from erp_purch_bil a 
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
-- 采购订单主表
DROP TRIGGER IF EXISTS `tr_erp_purch_bil_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_AFTER_INSERT` AFTER INSERT ON autopart01_erp.erp_purch_bil FOR EACH ROW BEGIN
	declare aName VARCHAR(100);
	insert into `autopart01_erp`.`erp_purch_bilwfw` (`billId`,`billStatus`,`userId`,`name`,`opTime`) 
		values (new.id, 'justcreated', new.`creatorId`, '刚刚创建', CURRENT_TIMESTAMP());
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能写入销售订单状态表!';
		end if;
	if new.erp_inquiry_bil_id > 0 then -- 是询价单自动转入
		if not exists(select 1 from erp_purch_bil a INNER JOIN erp_purch_detail b on a.id = b.erp_purch_bil_id limit 1) THEN
			-- 生成采购订单明细
			insert into erp_purch_detail(erp_purch_bil_id, goodsId, qty, price, createdDate)
			select new.id, a.goodsId, a.amount, a.priceCome, CURRENT_TIMESTAMP()
			from erp_vendi_detail a 
			where a.erp_inquiry_bil_id = new.erp_inquiry_bil_id and a.supplierId = new.supplierId 
				and a.isBuy = 1  and a.isEnough = 0 
			;
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '生成采购明细时出错！';
			end if;
		end if;
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

-- 货运信息表
drop table if exists erp_purch_pick;
CREATE TABLE `erp_purch_pick` (
  `erp_purch_bil_id` bigint(20) NOT NULL COMMENT '采购订单ID',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
	empId BIGINT(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
	pickTime datetime NULL COMMENT  '提货时间。',
	endTime datetime NULL COMMENT  '签收时间。非空表示仓库已签收',
  `opTime` datetime NOT NULL COMMENT  '日期时间；--@CreatedDate',
  `pickNo` varchar(100) DEFAULT NULL COMMENT '货运单号 非空为已提货',
  `memo` varchar(255) DEFAULT NULL COMMENT '货物中途信息',
  PRIMARY KEY (`erp_purch_bil_id`),
  KEY `erp_purch_pick_userId_idx` (`userId`),
  KEY `erp_purch_pick_opTime_idx` (`opTime`),
  CONSTRAINT `fk_erp_purch_pick_erp_purch_bil_id` FOREIGN KEY (`erp_purch_bil_id`) 
		REFERENCES `erp_purch_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
COMMENT='采购提货物流流程步骤＃--sn=TB04007&type=mdsFlow&jname=VenditionDeliverBillStep&title=销售发货物流状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}'
;
-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_pick_before_update`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_pick_before_update` BEFORE update ON autopart01_erp.erp_purch_pick FOR EACH ROW BEGIN
	if new.pickNo > '' and isnull(old.pickNo) THEN
		set new.pickTime = CURRENT_TIMESTAMP();
	end if;
end;;
DELIMITER ;
-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_bilwfw_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_bilwfw` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName varchar(100);
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
		-- 生成汇款单（用视图实现）
		
		-- 生成提货信息表
		insert into erp_purch_pick(erp_purch_bil_id, userId, empId, empName, opTime)
		select new.billId, new.userId, new.empId, new.empName, CURRENT_TIMESTAMP()
		;
	elseif new.billStatus = 'checked' then -- 审核修改付款时间
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'checked') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已汇款，不能重复操作！';
		end if;
		update erp_purch_bil a set a.costTime = CURRENT_TIMESTAMP() where a.id = new.billId;
		
	elseif new.billStatus = 'flowaway' then -- 进仓完成, 修改进仓时间表示已完成进仓
		update erp_purch_bil a 
		set a.inTime = CURRENT_TIME()
			, a.inUserId = new.userId, a.inEmpId = aid, a.inEmpName = aName
		where a.id = new.billId;
		-- 修改相应销售单的isEnough = 1
		UPDATE erp_vendi_detail a INNER JOIN erp_purch_bil b on a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
		set a.isEnough = 1
		where a.id = new.billId;
	end if;
end;;
DELIMITER ;