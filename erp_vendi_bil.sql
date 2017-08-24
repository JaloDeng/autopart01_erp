-- DROP TABLE IF EXISTS erp_vendi_bil;
-- CREATE TABLE `erp_vendi_bil` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `erp_inquiry_bil_id` bigint(20) DEFAULT NULL COMMENT '来源单编码 从询价单转入的由触发器自动填入，否则为空',
--   `customerId` bigint(20) NOT NULL COMMENT '客户 从询价单转入的由触发器自动填入，否则新增时用户界面选择',
--   `creatorId` bigint(20) NOT NULL COMMENT '登录账户ID 初建人编码；--@CreatorId',
--   `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
--   `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名。如果是询价单转，是执行checked的员工，否则是直接新增的员工',
--   `zoneNum` varchar(30) DEFAULT NULL COMMENT '客户所在地区的区号 触发器获取',
--   `code` varchar(100) NOT NULL COMMENT '单号 新增时触发器生成',
--   `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
--   `createdBy` varchar(255) DEFAULT NULL COMMENT '登录账户名称  初建人员；--@CreatedBy',
--   `costTime` datetime DEFAULT NULL COMMENT '交费时间',
--   `outTime` datetime DEFAULT NULL COMMENT '出仓时间 非空时已出仓可发货',
--   `outUserId` bigint(20) DEFAULT NULL COMMENT '出仓人 ',
--   `outEmpId` bigint(20) DEFAULT NULL COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
--   `outEmpName` varchar(100) DEFAULT NULL COMMENT '员工姓名。如果是询价单转，是执行checked的员工，否则是直接新增的员工',
--   `lastModifiedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
--   `lastModifiedId` bigint(20) DEFAULT NULL COMMENT '最新修改人编码；正常是审核人 触发器维护 --',
--   `lastModifiedEmpId` bigint(20) DEFAULT NULL COMMENT '最新修改人员工ID；触发器维护 erc$staff_id',
--   `lastModifiedEmpName` varchar(100) DEFAULT NULL COMMENT '最新修改员工姓名',
--   `lastModifiedBy` varchar(255) DEFAULT NULL COMMENT '最新人员；--@LastModifiedBy',
--   `needTime` datetime DEFAULT NULL COMMENT '期限时间  客户要求什么时间到货',
--   `erc$telgeo_contact_id` bigint(20) DEFAULT NULL COMMENT '公司自提，提货地址和电话_id',
--   `takeGeoTel` varchar(1000) DEFAULT NULL COMMENT '提货地址和电话；--这里用文本不用ID，防止本单据流程中地址被修改了',
--   `memo` varchar(2000) DEFAULT NULL COMMENT '备注',
--   PRIMARY KEY (`id`),
--   KEY `erp_vendi_bil_erp_inquiry_bil_id_idx` (`erp_inquiry_bil_id`),
--   KEY `erp_vendi_bil_creatorId_idx` (`creatorId`),
--   KEY `erp_vendi_bil_lastModifiedId_idx` (`lastModifiedId`),
--   KEY `erp_vendi_bil_createdDate_idx` (`createdDate`),
--   CONSTRAINT `fk_erp_vendi_bil_erp_inquiry_bil_id` FOREIGN KEY (`erp_inquiry_bil_id`) REFERENCES `erp_inquiry_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售订单主表＃--sn=TB04001&type=mdsMaster&jname=VenditionBill&title=销售订单&finds={"createdDate":1,"lastModifiedDate":1}'
-- ;

DROP TRIGGER IF EXISTS tr_erp_vendi_bil_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_bil` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName varchar(100);
	
	if exists(select 1 from autopart01_crm.`erc$customer` a where a.id = new.customerId limit 1) then
		set new.zoneNum = (select a.zonenum from autopart01_crm.`erc$customer` a where a.id = new.customerId);
		if isnull(new.zoneNum) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未指定客户的电话区号！',MYSQL_ERRNO = 1001;
		end if;
	else
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售单，必须指定有效的客户！';
	end if;
	if isnull(new.empId) then 
		if exists(select 1 from autopart01_crm.`erc$staff` a where a.userId = new.creatorId) THEN
			select a.id, a.name into aid, aName
			from autopart01_crm.`erc$staff` a where a.userId = new.creatorId;
			set new.empId = aid, new.empName = aName;
		ELSE
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增销售单，必须指定创建人！';
		end if;
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

	set new.lastModifiedId = new.creatorId, new.lastModifiedEmpId = aid
				, new.lastModifiedEmpName = aName ,new.lastModifiedDate = CURRENT_TIMESTAMP();		
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

DROP TRIGGER IF EXISTS tr_erp_vendi_bil_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_AFTER_INSERT` AFTER INSERT ON `erp_vendi_bil` FOR EACH ROW begin
	-- 写入销售单流程状态表
	insert into autopart01_erp.erp_vendi_bilwfw(billId, billstatus, userid, empId, empName, name, optime)
	select new.id, 'justcreated', new.creatorId, new.empId, new.empName, '刚刚创建',  CURRENT_TIMESTAMP()
;
	
	if new.erp_inquiry_bil_id > 0 then  -- 询价单转过来的销售单
		-- 登记销售明细对应的销售订单主表ID
		update erp_vendi_detail a inner join erp_inquiry_bil b on b.id = a.erp_inquiry_bil_id
		set a.erp_vendi_bil_id = new.id
		where b.id = new.erp_inquiry_bil_id and a.isBuy = 1;
		if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能登记销售明细对应的销售订单主表!';
		end if;
	end if;
end;;
DELIMITER ;

DROP TRIGGER IF EXISTS tr_erp_vendi_bil_BEFORE_UPDATE;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bil_BEFORE_UPDATE` BEFORE UPDATE ON `erp_vendi_bil` FOR EACH ROW BEGIN
	IF new.erc$telgeo_contact_id > 0 and 
		(isnull(old.erc$telgeo_contact_id) or new.erc$telgeo_contact_id <> old.erc$telgeo_contact_id)THEN
		SET new.takeGeoTel = (SELECT concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
			FROM autopart01_crm.erc$telgeo_contact a WHERE a.id = new.erc$telgeo_contact_id
		);
	END IF;
end;;
DELIMITER ;


-- DROP TRIGGER IF EXISTS tr_erp_vendi_bil_before_update;
-- DELIMITER ;;
-- CREATE TRIGGER `tr_erp_vendi_bil_before_update` BEFORE UPDATE ON `erp_vendi_bil` FOR EACH ROW BEGIN
-- 	if exists(select 1 from erp_vendi_bilwfw a where a.billId = new.id and a.billStatus = 'submitthatview') THEN
-- 		if new.creatorId <> old.creatorId then
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '订单已提交审核，不能修改创建者！';
-- 		elseif new.customerId <> old.customerId then
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '订单已提交审核，不能修改客户！';
-- 		end if;
-- 	else
-- 	if exists(select 1 from erp_vendi_bilwfw a where a.billId = new.id and a.billStatus = 'checked') THEN
-- 			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '订单已审核通过，不能修改！';
-- -- 	else
-- -- 		insert into erp_vendi_bilwfw(billId, billStatus, userId, name, opTime) 
-- -- 		values (new.id, 'selfupdated', new.lastModifiedId, '自行修改', CURRENT_TIMESTAMP());
-- 	end if;
-- 		IF EXISTS
-- end;;
-- DELIMITER ;