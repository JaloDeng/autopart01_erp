DROP TABLE IF EXISTS erp_purch_pick;
CREATE TABLE `erp_purch_pick` (
  `erp_purch_bil_id` bigint(20) NOT NULL COMMENT '采购订单ID',
  `userId` bigint(20) NOT NULL COMMENT '用户编码',
  `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
  `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
  `pickTime` datetime DEFAULT NULL COMMENT '提货时间。',
  `endTime` datetime DEFAULT NULL COMMENT '签收时间。非空表示仓库已签收',
  `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
  `pickNo` varchar(100) DEFAULT NULL COMMENT '货运单号 非空为已提货',
  `memo` varchar(255) DEFAULT NULL COMMENT '货物中途信息',
  PRIMARY KEY (`erp_purch_bil_id`),
  KEY `erp_purch_pick_userId_idx` (`userId`),
  KEY `erp_purch_pick_opTime_idx` (`opTime`),
  CONSTRAINT `fk_erp_purch_pick_erp_purch_bil_id` FOREIGN KEY (`erp_purch_bil_id`) REFERENCES `erp_purch_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购提货物流流程步骤＃--sn=TB04007&type=mdsFlow&jname=VenditionDeliverBillStep&title=销售发货物流状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}'
;

DROP TRIGGER IF EXISTS tr_erp_purch_pick_before_update;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_pick_before_update` BEFORE UPDATE ON `erp_purch_pick` FOR EACH ROW BEGIN
	if new.pickNo > '' and isnull(old.pickNo) THEN
		set new.pickTime = CURRENT_TIMESTAMP();
	end if;
end;;
DELIMITER ;