


SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- 系统一些默认参数 Table structure for sys_set
-- ----------------------------
DROP TABLE IF EXISTS `sys_set`;
CREATE TABLE `sys_set` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `value` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`)
	, key sys_set_name_idx(name) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
INSERT INTO `sys_set` VALUES ('1', 'ratio', '1.3'); -- 商品售价默认比率
INSERT INTO `sys_set` VALUES ('2', 'floatMin', '1.1'); -- 商品售价默认浮动下限
INSERT INTO `sys_set` VALUES ('3', 'floatMax', '1.4'); -- 商品售价默认浮动上限

drop view if exists v_goodsDefultRule;
create view v_goodsDefultRule as 
select 
	max(case when name = 'ratio' then value else null end) as ratio
	, max(case when name = 'floatMin' then value else null end) as floatMin
	, max(case when name = 'floatMax' then value else null end) as floatMax
from sys_set
;
-- ----------------------------
-- 商品表 Table structure for erp$goods
-- ----------------------------
DROP TABLE IF EXISTS `erp_goods`;
CREATE TABLE `erp_goods` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `itemId` bigint(20) NOT NULL COMMENT '汽配配件库的配件ID',
	name varchar(100) not null COMMENT '配件名称。可通过汽配配件库的配件ID获取， 冗余的原因是为了减少连接',
  `brand` varchar(255) DEFAULT NULL COMMENT '品牌',
  `origin` varchar(255) DEFAULT NULL COMMENT '产地',
  `exchangeCode` varchar(255) DEFAULT NULL COMMENT '交换码',
  `unit` varchar(30) DEFAULT NULL COMMENT '计量单位',
  `price` decimal(20,4) NOT NULL DEFAULT '0.00' COMMENT '销售均价',
  `newPrice` decimal(20,4) DEFAULT NULL COMMENT '最新售价',
  `minPrice` decimal(20,4) NULL DEFAULT NULL COMMENT '历史最低销售价，未销售为空',
  `maxPrice` decimal(20,4) NULL DEFAULT NULL COMMENT '历史最高销售价，未销售为空',
  `verlock` BIGINT(20) default null  COMMENT '乐观锁' /*乐观锁*/
  , PRIMARY KEY (`id`)
  , UNIQUE KEY `itemid` (`itemId`,`brand`,`origin`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;

-- ----------------------------
-- 调价规则配置Table structure for erp_conf_price_tune_rule
-- ----------------------------
DROP TABLE IF EXISTS `erp_conf_price_tune_rule`;
CREATE TABLE `erp_conf_price_tune_rule` (
  `goodsId` bigint(20) NOT NULL,
  `name` varchar(255) default NULL COMMENT '规则名称',
  `ratio` decimal(20,6) DEFAULT NULL COMMENT '转换率',
  `floatMin` decimal(20,6) DEFAULT NULL COMMENT '浮动下限',
  `floatMax` decimal(20,6) DEFAULT NULL COMMENT '浮动上限',
  `script` varchar(2000) DEFAULT NULL COMMENT '转换函数',
  PRIMARY KEY (`goodsId`),
  KEY `erp_conf_price_tune_rule_name_idx` (`name`),
  CONSTRAINT `fk_erp_conf_price_tune_rule_goodsid` FOREIGN KEY (`goodsId`) 
	REFERENCES `erp_goods` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
COMMENT='调价规则配置＃--sn=TB01505&type=oneOwn&jname=ConfigPriceTuneRule&title=&finds={"pathCode":1,"name":1,"itemType":1}'
;

/*ErsPackageAttr 包裹货品属性 有的商品有多种包装形式*/
DROP TABLE IF EXISTS `ers_packageAttr`;
CREATE TABLE ers_packageAttr (
`id` BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码' /*自增编码*/
  ,`parentId` BIGINT(20) default null  COMMENT '上级包裹' /*上级包裹*/
  , degree int COMMENT '包裹树结构的深度' /*上级包裹*/
  ,`goodsId` BIGINT(20) NOT NULL  COMMENT '货品编码' /*货品编码*/
  ,`actualQty` DECIMAL(20,4) NOT NULL  COMMENT '包裹中的实际容纳数量' /*容纳数量*/
  ,`childCount` BIGINT(20) NOT NULL  COMMENT '下层结点量；--仅仅往下一层的孩子结点数量' /*下层结点量*/
  ,`packageUnit` VARCHAR(30) NOT NULL  COMMENT '包裹单位。件、包、箱等' /*包裹单位*/
  ,`title` VARCHAR(255) NOT NULL  COMMENT '包裹名称；--相当于商品简称或打印小票名称' /*包裹名称*/
	, spec varchar(150) DEFAULT null COMMENT '长宽高'
	, volume decimal(20, 4) DEFAULT null COMMENT '容积'
--   ,`snCode` VARCHAR(255) default null  COMMENT '包裹编号；--扫描码可按规则生成或人手录入' /*包裹编号*/
  ,`tierCode` VARCHAR(255) default null  COMMENT '层级编码；--[p1Id,p2Id,p3Id]格式JSON(mysql57)支持深度最大11' /*层级编码*/
  ,`memo` VARCHAR(255) default null  COMMENT '包裹说明' /*包裹说明*/
  ,PRIMARY KEY (id)
  ,INDEX ers_packageAttr_goodsId_idx (goodsId)
  ,UNIQUE INDEX ers_packageAttr_title_idx (title)
	, key ers_packageAttr_parentId_idx(parentId)
--   ,UNIQUE INDEX snCode_idx (snCode)
--   ,INDEX erp_goodsPackage_tierCode_idx (tierCode)
	, CONSTRAINT `fk_ers_packageAttr_goodsid` FOREIGN KEY (`goodsid`) 
		REFERENCES erp_goods(`id`) ON DELETE CASCADE ON UPDATE CASCADE
	, CONSTRAINT `fk_ers_packageAttr_parentId` FOREIGN KEY (`parentId`) 
		REFERENCES ers_packageAttr(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE = InnoDB AUTO_INCREMENT=1 
COMMENT = '包裹货品属性＃--sn=TB02103&type=oneOwn&jname=ErsPackageAttr&title=&finds={"title":1,"snCode":1}';
-- -----------------------------------------------------------------------------------------------------------------------

drop TRIGGER if exists tr_ers_packageAttr_before_insert;
DELIMITER $$
CREATE TRIGGER `tr_ers_packageAttr_before_insert` BEFORE INSERT ON `ers_packageAttr`
FOR EACH ROW begin
	DECLARE aid int;
	declare iCount int;  -- 计数器 初始值 = 包裹深度
	declare aQty dec(20,2);  -- 组成单位的数量
	declare tQty dec(20,2);  -- 包裹包含的单品的数量
	declare tCode varchar(255);  -- 生成的tierCode
	if new.parentId > 0 then
		if new.childCount < 2 or isnull(new.childCount) THEN
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '新增商品非单品包装规格时，组成单位的数量必须大于1！';
		end if;
		set new.degree = (select a.degree + 1 from ers_packageAttr a where a.id = new.parentId);
		set aid = new.parentId, tQty = new.childCount;
		set iCount = new.degree - 1;
		set tCode = concat(aid, ']');
		if iCount > 1 then
			set tCode = concat(',', tCode); 
			while iCount > 1 do
				select a.parentId, a.childCount * tQty into aid, tQty
				from ers_packageAttr a where a.id = aid;
				set tCode = concat(aid, tCode);
				set iCount = iCount - 1;
				if iCount > 1 then 
					set tCode = concat(',', tCode); 
				ELSE
					set tCode = concat('[', tCode); 
				end if;
			end while; 
		ELSE
			set tCode = concat('[', tCode); 
		end if;
		set new.actualQty = tQty, new.tierCode = tCode;
	ELSE
		set new.degree = 1, new.actualQty = 1, new.childCount = 1, new.tierCode = '[]';
	end if;
end$$
DELIMITER ;

-- *****************************************************************************************************
-- 创建函数 uf_ers_packageAttr_getTierCode, 通过包裹ID获取 TierCode
-- *****************************************************************************************************
drop FUNCTION if exists uf_ers_packageAttr_getTierCode;
DELIMITER $$
create FUNCTION uf_ers_packageAttr_getTierCode(
	aid int -- 包裹ID
)
RETURNS varchar(255)
begin
	declare iCount int;  -- 计数器 初始值 = 包裹深度
	declare str varchar(255);  -- 生成的tierCode

	set iCount = (select a.degree from ers_packageAttr a where a.id = aid);
	if iCount = 1 THEN
		set str = '[]';
	else
		set str = ']';
		while iCount > 1 do
			set aid = (select a.parentId from ers_packageAttr a where a.id = aid);
			set str = concat(aid, str);
			set iCount = iCount - 1;
			if iCount > 1 then 
				set str = concat(',', str); 
			ELSE
				set str = concat('[', str); 
			end if;
		end while; 
	end if;
	return str;
end$$
DELIMITER ;

-- ----------------------------
-- 库存表 Table structure for erp_goodsbook
-- ----------------------------
DROP TABLE IF EXISTS `erp_goodsbook`;
CREATE TABLE `erp_goodsbook` (
  `goodsId` BIGINT(20) NOT NULL COMMENT '商品编码',
  `staticQty` int(11) NOT NULL DEFAULT '0' COMMENT '静态库存，不能为空，用户不指定写入0。所有核算、结算的单据以及报表情况，都是以审核后的单据为准。',
  `dynamicQty` int(11) NOT NULL DEFAULT '0' COMMENT '动态库存，不能为空，用户不指定写入0。单据录入并保存后需要修改此数量',
  `suppliersId` int(11) DEFAULT NULL COMMENT '最新的供应商编号，有新的进货单位就写入',
  `minqty` int(11) NOT NULL DEFAULT '5' COMMENT '低库存量',
	`price` decimal(20,2) NOT NULL DEFAULT '0.00' COMMENT '进货均价',
  `newPrice` decimal(20,4) NOT NULL DEFAULT '0.00' COMMENT '最新进货价，不能为空，用户不指定写入0',
  `minPrice` decimal(20,4) NULL DEFAULT NULL COMMENT '最低进货价，未进货为空',
  `maxPrice` decimal(20,4) NULL DEFAULT NULL COMMENT '最高进货价，未进货为空',
  `changeDate` char(10) DEFAULT NULL COMMENT '库存变更时的日期，系统后台维护和使用',
  `remarks` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`goodsid`),
  KEY `fk_erp_goodsbook_suppliersId_idx` (`suppliersId`)
-- ,  KEY `fk_erp_goodsbook_warehouseid_idx` (`warehouseid`),
  , CONSTRAINT `fk_erp_goodsbook_goodsId` FOREIGN KEY (`goodsId`) 
		REFERENCES erp_goods(`id`) ON DELETE NO ACTION ON UPDATE CASCADE
--  , CONSTRAINT `fk_erp_goodsbook_suppliersId` FOREIGN KEY (`suppliersId`) 
-- 		REFERENCES autopart01_crm.`erc$supplier` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='商品账簿';


DROP TRIGGER IF EXISTS `tr_erp_goodsbook_BEFORE_INSERT`;
-- DELIMITER ;;
-- CREATE TRIGGER `tr_erp_goodsbook_BEFORE_INSERT` BEFORE INSERT ON `erp_goodsbook` FOR EACH ROW begin
-- 	if isnull(new.suppliersId) or (not exists(select 1 from autopart01_crm.erc$supplier a where a.id = new.suppliersId) then
-- 		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '新增商品账簿时，必须指定有效的供应商！';
-- 	end if;
-- end;;
-- DELIMITER ;

DROP TRIGGER IF EXISTS `tr_erp_goodsbook_BEFORE_UPDATE`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_goodsbook_BEFORE_UPDATE` BEFORE UPDATE ON `erp_goodsbook` FOR EACH ROW begin
	if new.changeDate is null then set new.changeDate = CURDATE(); end if;
end;;
DELIMITER ;


-- -------------------------------------------------------------------------------------------
-- 创建表 erp_goods 的 BEFORE insert 触发器
drop TRIGGER if exists `tr_erp_goods_BEFORE_INSERT`;
DELIMITER $$
CREATE TRIGGER `tr_erp_goods_BEFORE_INSERT` BEFORE INSERT ON `erp_goods` FOR EACH ROW 
begin
	if new.itemId > 0 and exists(select 1 from autopart01_modeldb.`erv$vhcl_part` a where a.id = new.itemId) then
		set new.name = (select a.name from autopart01_modeldb.`erv$vhcl_part` a where a.id = new.itemId);
	ELSE
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '新增商品时，必须指定有效的配件！';
	end if;
end$$
DELIMITER ;
-- -------------------------------------------------------------------------------------------
-- 创建表 erp_goods 的 after insert 触发器
drop TRIGGER if exists `tr_erp_goods_AFTER_INSERT`;
DELIMITER $$
CREATE TRIGGER `tr_erp_goods_AFTER_INSERT` AFTER INSERT ON `erp_goods` FOR EACH ROW 
begin
  DECLARE msg VARCHAR(1000);
	if new.id > 0 then
		insert into erp_goodsbook(goodsid)
		select new.id;
		IF ROW_COUNT() <> 1 THEN
			set msg =  CONCAT('新增商品" ', new.name, ' "的记录时, 无法创建商品账簿！') ;  
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg; 
		end if;
		INSERT INTO `ers_packageAttr` (goodsId, degree, actualQty, childCount
			, packageUnit, title)
		select new.id, 1 as degree, 1 as actualQty, 1 as childCount
			, '个' as packageUnit, concat(new.name, '单品')
		;
		IF ROW_COUNT() <> 1 THEN
			set msg =  CONCAT('新增商品" ', new.name, ' "的记录时, 无法创建商品单品包装！') ;  
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg; 
		end if;
	else
		set msg = CONCAT('未指定商品，无法新增商品记录！') ;
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg; 
	end if;
end$$
DELIMITER ;
insert into erp_goods(itemId, name, brand, origin, exchangeCode)
select 1, '灯泡', '丰田', '武汉', '12345';

-- insert into erp$conf_price_tune_rule(goodsId, name, ratio, floatMin, floatMax)
-- values(1, '基本规则', 1.2, 1.1, 1.3);

-- INSERT INTO `ers_packageAttr` (parentId, degree, goodsId, actualQty, childCount, packageUnit, title, tierCode)
-- -- select NULL, 1 as degree, 1 as goodsId, 1.0000,0, '个', '灯泡单个', '[]'
-- -- union all 
-- select 1, 2 as degree, 1 as goodsId, 4.0000,4, '包', '灯泡4个1包', '[1]')
-- union all select 2, 3 as degree, 1 as goodsId, 20.0000,5, '盒', '灯泡5包1盒20个', '[1,2]'
-- union all select 3, 4 as degree, 1 as goodsId, 40.0000,2, '箱', '灯泡2盒1箱40个', '[1,2,3]';

INSERT INTO `ers_packageAttr` (parentId, degree, goodsId, childCount, packageUnit, title)
-- select NULL, 1 as degree, 1 as goodsId, 1.0000,0, '个', '灯泡单个', '[]'
-- union all 
select 1, 2 as degree, 1 as goodsId,4, '包', '灯泡4个1包'
union all select 2, 3 as degree, 1 as goodsId,5, '盒', '灯泡5包1盒20个'
union all select 3, 4 as degree, 1 as goodsId,2, '箱', '灯泡2盒1箱40个';

drop table if EXISTS erp_suppliersGoods;
CREATE TABLE `erp_suppliersGoods` (
	`crm_suppliers_id`  int NOT NULL ,
	`goodsId`  BIGINT(20) NOT NULL ,
	newPrice		DECIMAL(20,4) null COMMENT '最新进货价'
	, PRIMARY KEY (goodsId, crm_suppliers_id)
	, key erp_suppliersGoods(goodsId)
-- 	, CONSTRAINT `fk_erp_suppliersGoods_crm_suppliers_id` 
-- 		FOREIGN KEY (`crm_suppliers_id`) REFERENCES autopart01_crm.`erc$supplier` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
	, CONSTRAINT `fk_erp_suppliersGoods_goodsId` 
		FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
)ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='商品供应商'
;

-- -------------------------------------------------------------------------
/*ErsRoomAttr 仓库库房*/
drop table if EXISTS ers_roomAttr;
CREATE TABLE ers_roomAttr (
`id` BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码' /*自增编码*/
  ,`parentId` BIGINT(20) default null  COMMENT '上级仓库' /*上级仓库*/
	, degree int not null COMMENT '仓库级别' /*上级仓库*/
  ,`title` VARCHAR(100) NOT NULL  COMMENT '库房名称' /*库房名称*/
  ,`snCode` VARCHAR(255) default null  COMMENT '库房编号' /*库房编号*/
  ,`address` VARCHAR(255) default null  COMMENT '库房地址' /*库房地址*/
  ,`tierCode` VARCHAR(255)  default null COMMENT '层级编码' /*层级编码*/
  ,PRIMARY KEY (id)
  ,UNIQUE INDEX ers_roomAttr_title_UNIQUE (title)
  ,UNIQUE INDEX ers_roomAttr_snCode_UNIQUE (snCode)
	, key ers_roomAttr_parentId(parentId)
--   ,INDEX tierCode_idx (tierCode)
	, CONSTRAINT `fk_ers_roomAttr_parentId` FOREIGN KEY (`parentId`) 
		REFERENCES ers_roomAttr(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) AUTO_INCREMENT=1 
COMMENT = '仓库库房＃--sn=TB02101&type=oneOwn&jname=ErsRoomAttr&title=&finds={"title":1,"snCode":1}', ENGINE = InnoDB;


/*ErsShelfAttr 仓库货架*/
drop table if EXISTS ers_shelfAttr;
CREATE TABLE ers_shelfAttr (
`id` BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码' /*自增编码*/
  ,`roomId` BIGINT(20) not null  COMMENT '仓库编码' /*仓库编码*/
  ,`title` VARCHAR(100) NOT NULL  COMMENT '货架名称' /*货架名称*/
  ,`snCode` VARCHAR(255) default null  COMMENT '货架编号' /*货架编号*/
  ,PRIMARY KEY (id)
--   ,INDEX roomId_idx (roomId)
  ,UNIQUE INDEX roomId_title_UNIQUE (roomId,title)
	, key ers_shelfAttr_title(title)
  ,UNIQUE INDEX snCode_UNIQUE (snCode)
	, CONSTRAINT `fk_ers_shelfAttr_roomId` FOREIGN KEY (`roomId`) 
		REFERENCES ers_roomAttr(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) AUTO_INCREMENT=1 
 COMMENT = '仓库货架＃--sn=TB02102&type=oneOwn&jname=ErsShelfAttr&title=&finds={"title":1,"snCode":1}', ENGINE = InnoDB;

-- -------------------------------------------------------------------------------------------
-- 创建表 ers_roomAttr 的 AFTER INSERT 触发器
drop TRIGGER if exists `tr_ers_roomAttr_AFTER_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_roomAttr_AFTER_INSERT` AFTER INSERT ON ers_roomAttr FOR EACH ROW begin
	DECLARE msg VARCHAR(1000);
	if not exists(select 1 from ers_shelfattr a where a.roomId = new.id limit 1) then
		insert into ers_shelfattr(roomId, title) 
		select new.id, concat(new.title, '虚拟货架')
		;
		IF ROW_COUNT() <> 1 THEN
			set msg =  CONCAT('新增仓库" ', new.title, ' "的记录时, 无法创建虚拟货架！') ;  
			SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = msg; 
		end if;
	end if;
end;;
DELIMITER ;

INSERT INTO `ers_roomattr`(degree, title) 
select 1, '灯具库房101' union all
select 1, '灯具库房403';
INSERT INTO `ers_shelfattr`(roomId, title) 
select 1, '灯具货架A1' union all
select 1, '灯具货架A2' union all
select 2, '灯具货架A1';

/*ErsRoomBook 库房货品账簿*/
drop table if EXISTS ers_roomBook;
CREATE TABLE ers_roomBook (
-- `id` BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码' /*自增编码*/
  `goodsId` BIGINT(20) NOT NULL  COMMENT '货品编码' /*货品编码*/
  ,`roomId` BIGINT(20) NOT NULL  COMMENT '仓库编码' /*仓库编码*/
  ,`staticQty` DECIMAL(20,4) NOT NULL  COMMENT '静态存量' /*静态存量*/
  ,`dynamicQty` DECIMAL(20,4) NOT NULL  COMMENT '动态存量' /*动态存量*/
  ,`verlock` BIGINT(20) NOT NULL  COMMENT '乐观锁' /*乐观锁*/
  ,PRIMARY KEY (goodsId, roomId)
--   ,INDEX goodsId_idx (goodsId)
  ,INDEX roomId_idx (roomId)
	, CONSTRAINT `fk_ers_roomBook_goodsId` 
		FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
	, CONSTRAINT `fk_ers_roomBook_roomId` FOREIGN KEY (`roomId`) 
		REFERENCES ers_roomAttr(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
--   ,INDEX verlock_idx (verlock)
)  ENGINE = InnoDB
 COMMENT = '库房货品账簿＃--sn=TB02201&type=oneOwn&jname=ErsRoomBook&title=';
-- ----------------------------------------------------------------------------------------
/*ErsShelfBook 货架货品账簿*/
drop table if EXISTS ers_shelfBook;
CREATE TABLE ers_shelfBook (
-- `id` BIGINT(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码' /*自增编码*/
  `goodsId` BIGINT(20) NOT NULL  COMMENT '货品编码' /*货品编码*/
  ,`roomId` BIGINT(20) default null  COMMENT '仓库编码；--由触发器维护。冗余可从货架获得对应仓库' /*仓库编码*/
  ,`shelfId` BIGINT(20) NOT NULL  COMMENT '货架编码' /*货架编码*/
  ,`staicQty` DECIMAL(20,4) NOT NULL default 0 COMMENT '静态存量' /*静态存量*/
  ,`dynamicQty` DECIMAL(20,4) NOT NULL default 0 COMMENT '动态存量' /*动态存量*/
  ,`verlock` BIGINT(20) NOT NULL  COMMENT '乐观锁' /*乐观锁*/
--   ,PRIMARY KEY (id)
  ,PRIMARY KEY (goodsId, shelfId)
--   ,INDEX goodsId_idx (goodsId)
  ,INDEX roomId_idx (roomId)
  ,INDEX shelfId_idx (shelfId)
--   ,INDEX verlock_idx (verlock)
	, CONSTRAINT `fk_ers_shelfBook_goodsId` 
		FOREIGN KEY (`goodsId`) REFERENCES `erp_goods` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
	, CONSTRAINT `fk_ers_shelfBook_shelfId` FOREIGN KEY (`shelfId`) 
		REFERENCES ers_shelfAttr(`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) COMMENT = '货架货品账簿＃--sn=TB02202&type=oneOwn&jname=ErsShelfBook&title=', ENGINE = InnoDB;

-- -------------------------------------------------------------------------------------------
-- 创建表 ers_shelfBook 的 BEFORE INSERT 触发器
drop TRIGGER if exists `tr_ers_shelfBook_BEFORE_INSERT`;
DELIMITER ;;
CREATE TRIGGER `tr_ers_shelfBook_BEFORE_INSERT` BEFORE INSERT ON ers_shelfBook FOR EACH ROW begin
	if new.shelfId > 0 and exists(select 1 from ers_shelfAttr a where a.id = new.shelfId) then
		set new.roomId = (select a.roomId from ers_shelfAttr a where a.id = new.shelfId);
	end if;
end;;
DELIMITER ;

-- select a.id, a.parentId, 
-- from ers_packageAttr a inner join ers_packageAttr b on a.id = b.parentId
-- group by a.id, a.parentId


select uf_ers_packageAttr_getTierCode(a.id), a.*
from ers_packageAttr a;
-- where a.id = 1

-- ALTER TABLE `ers_incomingbook`
-- CHANGE COLUMN `occurTime` `creatTime`  datetime NOT NULL COMMENT '日期时间' AFTER `id`,
-- CHANGE COLUMN `ivQty` `actualQty`  decimal(20,4) NOT NULL COMMENT '货品实际数量' AFTER `verlock`,
-- CHANGE COLUMN `pvQty` `packageQty`  bigint(20) NULL DEFAULT NULL COMMENT '包裹数量' AFTER `actualQty`,
-- CHANGE COLUMN `ivUnit` `actualUnit`  varchar(30) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT NULL COMMENT '货量单位' AFTER `packageQty`,
-- CHANGE COLUMN `pvUnit` `packageUnit`  varchar(30) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT NULL COMMENT '包裹单位' AFTER `actualUnit`;
-- 
-- CREATE TRIGGER `tr_ers_incomingbook_before_INSERT` BEFORE INSERT ON `ers_incomingbook`
-- FOR EACH ROW begin
-- 	if (select from ers_packageattr a where a.id)
-- end;

