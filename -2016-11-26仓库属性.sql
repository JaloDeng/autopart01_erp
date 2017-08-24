-- 新增仓库电话和负责人姓名
DROP TABLE IF EXISTS ers_roomattr;
CREATE TABLE `ers_roomattr` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `parentId` bigint(20) DEFAULT NULL COMMENT '上级仓库',
  `degree` int(11) NOT NULL COMMENT '仓库级别',
  `title` varchar(100) NOT NULL COMMENT '库房名称',
  `snCode` varchar(255) DEFAULT NULL COMMENT '库房编号',
  `address` varchar(255) DEFAULT NULL COMMENT '库房地址',
	`phone` VARCHAR(50) DEFAULT NULL COMMENT '仓库电话',
	`empId` bigint(20) DEFAULT NULL COMMENT '仓库负责人ID；erc$staff_id',
	`empName` VARCHAR(100) DEFAULT NULL COMMENT '仓库负责人',
  `tierCode` varchar(255) DEFAULT NULL COMMENT '层级编码',
  PRIMARY KEY (`id`),
  UNIQUE KEY `ers_roomAttr_title_UNIQUE` (`title`),
  UNIQUE KEY `ers_roomAttr_snCode_UNIQUE` (`snCode`),
  KEY `ers_roomAttr_parentId` (`parentId`),
  CONSTRAINT `fk_ers_roomAttr_parentId` FOREIGN KEY (`parentId`) REFERENCES `ers_roomattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COMMENT='仓库库房＃--sn=TB02101&type=oneOwn&jname=ErsRoomAttr&title=&finds={"title":1,"snCode":1}';


DROP TRIGGER IF EXISTS tr_ers_roomAttr_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_ers_roomAttr_BEFORE_INSERT` BEFORE INSERT ON `ers_roomattr` FOR EACH ROW begin
	DECLARE msg VARCHAR(1000);
	if new.empId is not null then
		set new.empName = (select a.name from autopart01_crm.`erc$staff` a where a.id = new.empId);
	end if;
end
;;
DELIMITER ;


DROP TRIGGER IF EXISTS tr_ers_roomAttr_AFTER_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_ers_roomAttr_AFTER_INSERT` AFTER INSERT ON `ers_roomattr` FOR EACH ROW begin
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
end
;;
DELIMITER ;