DROP TABLE IF EXISTS `erp_vendi_back_pick`;
CREATE TABLE `erp_vendi_back_pick` (
  `erp_vendi_back_id` bigint(20) NOT NULL COMMENT '采购订单ID',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
  `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
  `shipperId` bigint(20) DEFAULT NULL COMMENT '物流商id autopart01_crm.erc$shipper.id',
  `packageQty` int(11) DEFAULT NULL COMMENT '客户退货时打包件数',
  `shipperName` varchar(130) DEFAULT NULL COMMENT '物流商名称 冗余',
  `userName` varchar(100) DEFAULT NULL COMMENT '登陆用户名',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `pickTime` datetime DEFAULT NULL COMMENT '提货时间',
  `endTime` datetime DEFAULT NULL COMMENT '签收时间。非空表示仓库已签收',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `pickUserId` bigint(20) DEFAULT NULL COMMENT '提货人登录ID',
  `pickEmpId` bigint(20) DEFAULT NULL COMMENT '提货员工ID',
  `pickEmpName` varchar(100) DEFAULT NULL COMMENT '提货员工姓名',
  `lastModifiedId` bigint(20) DEFAULT NULL,
  `lastModifiedDate` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP COMMENT '最新时间',
  `inquiryCode` varchar(100) DEFAULT NULL COMMENT '询价单号，冗余',
  `pickNo` varchar(100) DEFAULT NULL COMMENT '货运单号 非空为已提货',
  `memo` varchar(255) DEFAULT NULL COMMENT '货物中途信息',
  `erc$telgeo_contact_id` bigint(20) DEFAULT NULL,
  `takeGeoTel` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`erp_vendi_back_id`),
  KEY `erp_vendi_back_pick_userId_idx` (`userId`),
  KEY `erp_vendi_back_pick_opTime_idx` (`opTime`),
  KEY `erp_vendi_back_pick_shipperId_idx` (`shipperId`) USING BTREE,
  KEY `erp_vendi_back_pick_inquiryCode_idx` (`inquiryCode`) USING BTREE,
  CONSTRAINT `fk_erp_vendi_back_pick_erp_vendi_back_id` FOREIGN KEY (`erp_vendi_back_id`) 
		REFERENCES `erp_vendi_back` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售退货提货单';

DROP TRIGGER IF EXISTS `tr_erp_vendi_back_pick_before_update`;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_back_pick_before_update` BEFORE UPDATE ON `erp_vendi_back_pick` FOR EACH ROW BEGIN
	DECLARE aId BIGINT(20);
	DECLARE aName, aUserName VARCHAR(100);

	-- 获取用户信息
	call p_get_userInfo(new.lastModifiedId, aId, aName, aUserName);
	-- 获取物流商
	if new.shipperId > 0 and (isnull(old.shipperId) or new.shipperId <> old.shipperId) then 
		set new.shipperName = (select a.name from autopart01_crm.erc$shipper a where a.id = new.shipperId);
	end if;
	-- 采购提货出发
	if new.pickUserId > 0 and isnull(old.pickUserId) THEN
		IF new.pickUserId <> new.lastModifiedId THEN
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '销售退货提货出发确认时，操作人和最新操作人必须是同一人！';
		END IF;
		call p_get_userInfo(new.lastModifiedId, aid, aName, aUserName);
		-- 记录提货出发员工
		set new.pickTime = CURRENT_TIMESTAMP(), new.pickEmpId = aId, new.pickEmpName = aName;
		-- 记录操作
		insert into erp_vendi_back_bilwfw(billId, billstatus, userId, empId, empName, userName, name)
		select new.erp_vendi_back_id, 'pickBegin', new.lastModifiedId, aId, aName, aUserName, '提货出发';
	-- 完成提货，仓库可进仓
	elseif new.endTime > 0 and isnull(old.endTime) THEN 
		UPDATE erp_vendi_back a SET a.isSubmit = 1, a.lastModifiedId = new.lastModifiedId WHERE a.id = new.erp_vendi_back_id;
	end if;
end;;
DELIMITER ;