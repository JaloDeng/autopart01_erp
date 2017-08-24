-- DROP TABLE IF EXISTS erp_purch_bil;
-- CREATE TABLE `erp_purch_bil` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `erp_inquiry_bil_id` bigint(20) DEFAULT NULL COMMENT '询价单ID。为空表示是公司直接采购',
--   `supplierId` bigint(20) NOT NULL COMMENT '供应商',
--   `creatorId` bigint(20) NOT NULL COMMENT '初建人编码；--@CreatorId',
--   `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
--   `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名。如果是询价单转，是执行checked的员工，否则是直接新增的员工',
--   `zoneNum` varchar(30) DEFAULT NULL COMMENT '客户所在地区的区号 触发器获取',
--   `code` varchar(100) NOT NULL COMMENT '单号 新增时触发器生成',
--   `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
--   `createdBy` varchar(100) DEFAULT NULL COMMENT '初建人员；--@CreatedBy 登录用户名',
--   `costTime` datetime DEFAULT NULL COMMENT '付款时间  为空的数据即为汇款申请的数据',
--   `inTime` datetime DEFAULT NULL COMMENT '进仓时间 非空时已出仓可发货',
--   `inUserId` bigint(20) DEFAULT NULL COMMENT '进人 ',
--   `inEmpId` bigint(20) DEFAULT NULL COMMENT '出仓员工ID；--@  erc$staff_id',
--   `inEmpName` varchar(100) DEFAULT NULL COMMENT '员工姓名。是执行checked的员工',
--   `lastModifiedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
--   `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新修改人编码；正常是审核人 触发器维护 --',
--   `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
--   `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新修改员工姓名',
--   `lastModifiedBy` varchar(255) DEFAULT NULL COMMENT '最新人员；--@LastModifiedBy',
--   `priceSumCome` decimal(20,4) DEFAULT NULL COMMENT '进价金额总计',
--   `priceSumShip` decimal(20,4) DEFAULT NULL COMMENT '运费金额总计',
--   `needTime` datetime DEFAULT NULL COMMENT '期限时间  客户要求什么时间到货',
--   `erc$telgeo_contact_id` bigint(20) DEFAULT NULL COMMENT '公司自提，提货地址和电话_id',
--   `takeGeoTel` varchar(1000) DEFAULT NULL COMMENT '提货地址和电话；--这里用文本不用ID，防止本单据流程中地址被修改了',
--   `memo` varchar(2000) DEFAULT NULL COMMENT '备注',
--   PRIMARY KEY (`id`),
--   UNIQUE KEY `code_UNIQUE` (`code`),
--   KEY `creatorId_idx` (`creatorId`),
--   KEY `createdDate_idx` (`createdDate`),
--   KEY `erp_inquiry_bil_id_idx` (`erp_inquiry_bil_id`),
--   CONSTRAINT `fk_erp_purch_bil_erp_inquiry_bil_id` FOREIGN KEY (`erp_inquiry_bil_id`) REFERENCES `erp_inquiry_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
-- ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='采购单主表＃--sn=TB03001&type=mdsMaster&jname=PurchaseBill&title=采购单&finds={"code":1,"createdDate":1}'
-- ;

DROP TRIGGER IF EXISTS tr_erp_purch_bil_BEFORE_INSERT;
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
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增采购单，必须指定有效的供应商！';
	end if;
	if isnull(new.empId) then
		if exists(select 1 from autopart01_crm.erc$staff a where a.userId = new.creatorId) THEN
			select a.id, a.name into aid, aName
			from autopart01_crm.`erc$staff` a where a.userId = new.creatorId;
			set new.empId = aid, new.empName = aName;	
		ELSE
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增采购单，必须指定创建人！';
		end if;
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
	-- 记录最后修改信息
	set new.lastModifiedId = new.creatorId, new.lastModifiedEmpId = aid
			, new.lastModifiedEmpName = aName ,new.lastModifiedDate = CURRENT_TIMESTAMP();	
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

DROP TRIGGER IF EXISTS tr_erp_purch_bil_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_AFTER_INSERT` AFTER INSERT ON `erp_purch_bil` FOR EACH ROW BEGIN
	declare aName VARCHAR(100);
	insert into `autopart01_erp`.`erp_purch_bilwfw` (`billId`,`billStatus`,`userId`,`name`,`opTime`) 
		values (new.id, 'justcreated', new.`creatorId`, '刚刚创建', CURRENT_TIMESTAMP());
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能写入销售订单状态表!';
		end if;
	if new.erp_inquiry_bil_id > 0 then -- 是询价单自动转入
		if not exists(select 1 from erp_purch_bil a INNER JOIN erp_purch_detail b on a.id = b.erp_purch_bil_id WHERE a.id = new.id limit 1) THEN
			-- 生成采购订单明细
			
			insert into erp_purch_detail(erp_purch_bil_id, goodsId, ers_packageAttr_id, packageQty, packagePrice, createdDate)
			select new.id, a.goodsId, a.ers_packageAttr_id, a.packageQty, a.price * b.actualQty, CURRENT_TIMESTAMP()
			from erp_vendi_detail a 
			LEFT JOIN ers_packageattr b ON b.id = a.ers_packageAttr_id  
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

DROP TRIGGER IF EXISTS tr_erp_purch_bil_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bil_BEFORE_UPDATE` BEFORE UPDATE ON `erp_purch_bil` FOR EACH ROW BEGIN
	IF new.erc$telgeo_contact_id > 0 and 
		(isnull(old.erc$telgeo_contact_id) or new.erc$telgeo_contact_id <> old.erc$telgeo_contact_id)THEN
		SET new.takeGeoTel = (SELECT concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
			FROM autopart01_crm.erc$telgeo_contact a WHERE a.id = new.erc$telgeo_contact_id
		);
	END IF;
end;;
DELIMITER ;