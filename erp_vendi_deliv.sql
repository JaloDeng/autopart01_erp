DROP TABLE IF EXISTS erp_vendi_deliv;
CREATE TABLE `erp_vendi_deliv` (
  `erp_vendi_bil_id` bigint(20) NOT NULL COMMENT '销售订单ID',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
  `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `delivTime` datetime DEFAULT NULL COMMENT '发货时间。非空表示已发货',
  `endTime` datetime DEFAULT NULL COMMENT '签收时间。非空表示客户已签收',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `delivNo` varchar(100) DEFAULT NULL COMMENT '货运单号 非空为已发货',
  `memo` varchar(255) DEFAULT NULL COMMENT '货物中途信息',
  PRIMARY KEY (`erp_vendi_bil_id`),
  KEY `userId_idx` (`userId`),
  KEY `opTime_idx` (`opTime`),
  CONSTRAINT `fk_erp_vendi_deliv_erp_vendi_bil_id` FOREIGN KEY (`erp_vendi_bil_id`) REFERENCES `erp_vendi_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='销售发货物流流程步骤＃--sn=TB04007&type=mdsFlow&jname=VenditionDeliverBillStep&title=销售发货物流状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}'
;

DROP TRIGGER IF EXISTS tr_erp_vendi_deliv_before_update;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_deliv_before_update` BEFORE UPDATE ON `erp_vendi_deliv` FOR EACH ROW BEGIN
	if new.delivNo > '' and isnull(old.delivNo) THEN
		set new.delivTime = CURRENT_TIMESTAMP();
	end if;
end;
DELIMITER ;