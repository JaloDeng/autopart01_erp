-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 采购提货单
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `erp_purch_pick`;
CREATE TABLE `erp_purch_pick` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
  `erp_purch_bil_id` bigint(20) NOT NULL COMMENT '采购订单ID',
  `supplierId` bigint(20) DEFAULT NULL COMMENT '供应商id autopart01_crm.erc$supplier.id',
  `supplierName` VARCHAR(100) DEFAULT NULL COMMENT '供应商名称，冗余',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
  `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
  `shipperId` bigint(20) DEFAULT NULL COMMENT '物流商id autopart01_crm.erc$shipper.id',
  `erp_payment_type_id` int(11) DEFAULT NULL COMMENT '支付方式',
  `packageQty` int(11) DEFAULT NULL COMMENT '供应商发货时打包件数',
  `shipperName` varchar(130) DEFAULT NULL COMMENT '物流商名称 冗余',
  `userName` varchar(100) DEFAULT NULL COMMENT '登陆用户名',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `serialNumber` varchar(191) DEFAULT NULL COMMENT '支付流水号',
  `pickTime` datetime DEFAULT NULL COMMENT '提货时间。',
  `endTime` datetime DEFAULT NULL COMMENT '签收时间。非空表示仓库已签收',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `pickUserId` bigint(20) DEFAULT NULL COMMENT '提货人登录ID',
  `pickEmpId` bigint(20) DEFAULT NULL COMMENT '提货员工ID',
  `pickEmpName` varchar(100) DEFAULT NULL COMMENT '提货员工姓名',
  `lastModifiedId` bigint(20) DEFAULT NULL,
  `lastModifiedDate` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '最新时间',
  `purchCode` varchar(100) DEFAULT NULL COMMENT '采购单号',
  `inquiryCode` varchar(100) DEFAULT NULL COMMENT '询价单号，冗余',
  `pickNo` varchar(100) DEFAULT NULL COMMENT '货运单号 非空为已提货',
  `memo` varchar(255) DEFAULT NULL COMMENT '货物中途信息',
  `erc$telgeo_contact_id` bigint(20) DEFAULT NULL,
  `takeGeoTel` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `erp_purch_pick_erp_purch_bil_id_idx` (`erp_purch_bil_id`, `supplierId`),
  KEY `erp_purch_pick_supplierId_idx` (`supplierId`),
  KEY `erp_purch_pick_opTime_idx` (`opTime`),
  KEY `erp_purch_pick_shipperId_idx` (`shipperId`) USING BTREE,
  KEY `erp_purch_pick_erp_payment_type_id_idx` (`erp_payment_type_id`) USING BTREE,
  KEY `erp_purch_pick_inquiryCode_idx` (`inquiryCode`) USING BTREE,
  KEY `erp_purch_pick_purchCode_idx` (`purchCode`) USING BTREE,
  CONSTRAINT `fk_erp_purch_pick_erp_payment_type_id` FOREIGN KEY (`erp_payment_type_id`) REFERENCES `erp_payment_type` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_erp_purch_pick_erp_purch_bil_id` FOREIGN KEY (`erp_purch_bil_id`) REFERENCES `erp_purch_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购提货物流流程步骤';

-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_pick_before_insert`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_pick_before_insert` BEFORE INSERT ON `erp_purch_pick` FOR EACH ROW BEGIN
	
	IF EXISTS(SELECT 1 FROM autopart01_crm.`erc$supplier` a WHERE a.id = new.supplierId) THEN
		SET new.supplierName = (SELECT a.`name` FROM autopart01_crm.`erc$supplier` a WHERE a.id = new.supplierId);
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '请指定有效供应商！！';
	END IF;

end;;
DELIMITER ;

-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_pick_before_update`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_pick_before_update` BEFORE UPDATE ON `erp_purch_pick` FOR EACH ROW BEGIN
	DECLARE aId BIGINT(20);
	DECLARE aName, aUserName VARCHAR(100);

	if new.shipperId > 0 and (isnull(old.shipperId) or new.shipperId <> old.shipperId) then 
		set new.shipperName = (select a.name from autopart01_crm.erc$shipper a where a.id = new.shipperId);
	end if;
	-- 采购提货出发
	if new.pickUserId > '' and isnull(old.pickUserId) THEN
		IF new.pickUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购提货出发确认时，操作人和最新操作人必须是同一人！';
		END IF;
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		set new.pickTime = CURRENT_TIMESTAMP(), new.pickEmpId = aId, new.pickEmpName = aName;
	-- 完成提货，仓库可进仓
	elseif new.endTime > 0 and isnull(old.endTime) THEN 
		UPDATE erp_purch_detail a SET a.isReceive = 1, a.lastModifiedId = new.lastModifiedId
		WHERE a.erp_purch_bil_id = new.erp_purch_bil_id AND a.supplierId = new.supplierId;
	end if;
end;;
DELIMITER ;

-- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_erp_purch_pick_after_update`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_pick_after_update` AFTER UPDATE ON `erp_purch_pick` FOR EACH ROW BEGIN
	-- 判断采购明细所有配件是否完成仓库签收
	if new.endTime > 0 and isnull(old.endTime) THEN
		IF NOT EXISTS(SELECT 1 FROM erp_purch_detail a 
			WHERE a.erp_purch_bil_id = new.erp_purch_bil_id AND a.isReceive = 0 LIMIT 1) THEN
				-- 更新采购单主表仓库签收标志位
				update erp_purch_bil a set a.isReceive = 1, a.lastModifiedId = new.lastModifiedId 
				where a.id = new.erp_purch_bil_id;
		END IF;
	end if;
end;;
DELIMITER ;