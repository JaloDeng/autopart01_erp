-- DROP TABLE IF EXISTS erp_purch_bilwfw;
-- CREATE TABLE `erp_purch_bilwfw` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `billId` bigint(20) DEFAULT NULL COMMENT '单码',
--   `billStatus` varchar(50) NOT NULL COMMENT '单状态',
--   `prevId` bigint(20) DEFAULT NULL COMMENT '前个步骤',
--   `userId` bigint(20) NOT NULL COMMENT '用户编码',
--   `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
--   `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
--   `name` varchar(255) NOT NULL COMMENT '步骤名称',
--   `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
--   `said` varchar(255) DEFAULT NULL COMMENT '步骤附言',
--   `memo` varchar(255) DEFAULT NULL COMMENT '其他关联',
--   PRIMARY KEY (`id`),
--   KEY `userId_idx` (`userId`),
--   KEY `billStatus_idx` (`billStatus`),
--   KEY `opTime_idx` (`opTime`),
--   KEY `FKCtb03003fk00000qunzhi` (`billId`),
--   KEY `FKCtb03003fk00001qunzhi` (`prevId`),
--   CONSTRAINT `fk_erp_purch_bilwfw_billId` FOREIGN KEY (`billId`) REFERENCES `erp_purch_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='采购单流程步骤＃--sn=TB03003&type=mdsFlow&jname=PurchaseBillStep&title=采购单状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}'
-- ;

DROP TRIGGER IF EXISTS tr_erp_purch_bilwfw_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_purch_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_purch_bilwfw` FOR EACH ROW begin
	declare aid bigint(20);
	DECLARE aName varchar(100);
	IF EXISTS(SELECT 1 FROM erp_purch_bilwfw a WHERE a.billId = new.billId AND a.billStatus = 'flowaway') THEN
		SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = '该采购单已进仓完成，不能重复操作！';
	END IF;
	if exists(select 1 from autopart01_crm.`erc$staff` a where a.userId = new.userId) THEN
		select a.id, a.name into aid, aName
		from autopart01_crm.`erc$staff` a where a.userId = new.userId;
		set new.empId = aid, new.empName = aName;
		set new.opTime = CURRENT_TIMESTAMP();
		if new.billStatus <> 'justcreated' then
			update erp_purch_bil a 
			set a.lastModifiedDate = CURRENT_TIMESTAMP(), a.lastModifiedId = new.userId
				, a.lastModifiedEmpId = new.empId, a.lastModifiedEmpName = new.empName
			where a.id = new.billId;
		END IF;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增操作记录，必须指定操作人员！';
	end if;
	if new.billStatus = 'submitthatview' then  -- 提交待审
		if exists(select 1 from erp_inquiry_bilwfw a where a.billId = NEW.billId and a.billStatus = 'submitthatview') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已提交，不能重复提交！';
		end if;
		-- 生成汇款单（用视图实现）
		if not exists(SELECT 1 from erp_purch_bil a where a.id = new.billId and a.erc$telgeo_contact_id > 0) then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购单提交审核时，必须指定提货地址！';
		end if;
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
		set a.inTime = CURRENT_TIMESTAMP()
			, a.inUserId = new.userId, a.inEmpId = aid, a.inEmpName = aName
		where a.id = new.billId;
		-- 修改相应销售单的isEnough = 1
		IF (SELECT a.erp_inquiry_bil_id FROM erp_purch_bil a WHERE a.id = new.billId) > 0 THEN 
			UPDATE erp_vendi_detail a INNER JOIN erp_purch_bil b on a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
			set a.isEnough = 1
			where b.id = new.billId;
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '采购订单入库，未能成功修改相应销售明细可以出仓标志！';
			end if;
		END IF;
	end if;
end;;
DELIMITER ;