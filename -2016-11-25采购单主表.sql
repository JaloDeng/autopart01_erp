-- 采购单主表
set foreign_key_checks = 0;

DROP TABLE IF EXISTS erp_purch_bil;
CREATE TABLE `erp_purch_bil` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_inquiry_bil_id` bigint(20) DEFAULT NULL COMMENT '询价单ID。为空表示是公司直接采购',
	`code` VARCHAR(100) NOT NULL COMMENT '采购单号,由触发器自动生成',
  `supplierId` bigint(20) NOT NULL COMMENT '供应商',
  `creatorId` bigint(20) NOT NULL COMMENT '初建人编码；--@CreatorId',
  `empId` bigint(20) DEFAULT NULL COMMENT '初建员工ID；--@ 公司的客服 erc$staff_id',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名。如果是询价单转，是执行checked的员工，否则是直接新增的员工',
  `createdDate` datetime DEFAULT NULL COMMENT '初建时间；--@CreatedDate',
  `createdBy` varchar(255) DEFAULT NULL COMMENT '初建人员；--@CreatedBy 登录用户名',
  `lastModifiedDate` datetime DEFAULT NULL COMMENT '最新时间；--@LastModifiedDate',
  `lastModifiedBy` varchar(255) DEFAULT NULL COMMENT '最新人员；--@LastModifiedBy',
  `priceSumCome` decimal(20,4) DEFAULT NULL COMMENT '进价金额总计',
  `priceSumShip` decimal(20,4) DEFAULT NULL COMMENT '运费金额总计',
  `erc$telgeo_contact_id` bigint(20) DEFAULT NULL COMMENT '公司自提，提货地址和电话_id',
  `takeGeoTel` varchar(1000) DEFAULT NULL COMMENT '提货地址和电话；--这里用文本不用ID，防止本单据流程中地址被修改了',
  `memo` varchar(2000) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
	UNIQUE KEY `erp_purch_bil_code_UNIQUE` (`code`),
  KEY `creatorId_idx` (`creatorId`),
  KEY `createdDate_idx` (`createdDate`),
  KEY `erp_inquiry_bil_id_idx` (`erp_inquiry_bil_id`),
  CONSTRAINT `fk_erp_purch_bil_erp_inquiry_bil_id` FOREIGN KEY (`erp_inquiry_bil_id`) REFERENCES `erp_inquiry_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购单主表＃--sn=TB03001&type=mdsMaster&jname=PurchaseBill&title=采购单&finds={"code":1,"createdDate":1}'
;

-- 采购单插入前触发器
DROP TRIGGER IF EXISTS tr_erp_purch_bil_BEFORE_INSERT;

DELIMITER ;;

CREATE TRIGGER `tr_erp_purch_bil_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_bil` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName varchar(100);
	if exists(select 1 from autopart01_crm.`erc$staff` a where a.userId = new.creatorId) THEN
		select a.id, a.name into aid, aName
		from autopart01_crm.`erc$staff` a where a.userId = new.creatorId;
		set new.empId = aid, new.empName = aName;
	ELSE
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '新增采购单，必须指定创建人！';
	end if;
	if new.erc$telgeo_contact_id > 0 THEN
		set new.takeGeoTel = (select concat('联系人:', a.person, '  联系号码:', a.callnum, ' 地址:', a.addrroad)
			from autopart01_crm.erc$telgeo_contact a where a.id = new.erc$telgeo_contact_id
		);
	end if;
	-- 生成code PB+8位日期+4位员工id+4位流水(从订单生成采购单时code为空)
	if new.erp_inquiry_bil_id is null THEN 
		set new.code = concat('PB', date_format(new.createdDate,'%Y%m%d'), LPAD(new.creatorId,4,0)
			, LPAD(
				ifnull((select max(right(a.code, 4)) from erp_purch_bil a 
					where date(a.createdDate) = date(new.createdDate) and a.creatorId = new.creatorId), 0
				) + 1, 4, 0)
		);
	end if;
end;;
DELIMITER ;

-- 采购单插入后触发器
DROP TRIGGER IF EXISTS tr_erp_purch_bil_AFTER_INSERT;

DELIMITER ;;

CREATE TRIGGER `tr_erp_purch_bil_AFTER_INSERT` AFTER INSERT ON `erp_purch_bil` FOR EACH ROW BEGIN
	declare aName VARCHAR(100);
	insert into `autopart01_erp`.`erp_purch_bilwfw` (`billId`,`billStatus`,`userId`,`name`,`opTime`) 
		values (new.id, 'justcreated', new.`creatorId`, '刚刚创建', CURRENT_TIMESTAMP());
		if ROW_COUNT() = 0 THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '未能写入销售订单状态表!';
		end if;
	if new.erp_inquiry_bil_id > 0 then -- 是询价单自动转入
		if not exists(select 1 from erp_purch_detail a 
			where a.erp_inquiry_bil_id = new.erp_inquiry_bil_id and a.supplierId = new.supplierId) THEN
			-- 生成采购订单明细
			insert into erp_purch_detail(erp_purch_bil_id, goodsId, qty, price, createdDate)
			select new.id, a.goodsId, a.amount, a.priceCome, CURRENT_TIMESTAMP()
			from erp_vendi_detail a 
			where a.isBuy = 1 AND a.erp_inquiry_bil_id = new.erp_inquiry_bil_id
					and a.supplierId = new.supplierId
			;
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '生成采购明细时出错！';
			end if;
		end if;
	end if;

end;;
DELIMITER ;
