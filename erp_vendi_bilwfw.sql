-- DROP TABLE IF EXISTS erp_vendi_bilwfw;
-- CREATE TABLE `erp_vendi_bilwfw` (
--   `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '自增编码',
--   `billId` bigint(20) DEFAULT NULL COMMENT '单码  erp_vendi_bil_id',
--   `billStatus` varchar(50) NOT NULL COMMENT '单状态',
--   `prevId` bigint(20) DEFAULT NULL COMMENT '前个步骤',
--   `userId` bigint(20) NOT NULL COMMENT '用户编码  登录帐号ID',
--   `empId` bigint(20) DEFAULT NULL COMMENT '员工ID',
--   `empName` varchar(100) DEFAULT NULL COMMENT '员工姓名',
--   `name` varchar(255) NOT NULL COMMENT '步骤名称',
--   `opTime` datetime NOT NULL COMMENT '日期时间；--@CreatedDate',
--   `said` varchar(255) DEFAULT NULL COMMENT '步骤附言',
--   `memo` varchar(255) DEFAULT NULL COMMENT '其他关联',
--   PRIMARY KEY (`id`),
--   KEY `erp_vendi_bilwfw_userId_idx` (`userId`),
--   KEY `erp_vendi_bilwfw_billStatus_idx` (`billId`,`billStatus`),
--   KEY `erp_vendi_bilwfw_status_idx` (`billStatus`),
--   KEY `erp_vendi_bilwfw_opTime_idx` (`opTime`),
--   CONSTRAINT `fk_erp_vendi_bilwfw_billId` FOREIGN KEY (`billId`) REFERENCES `erp_vendi_bil` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
-- ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='销售订单流程步骤＃--sn=TB03003&type=mdsFlow&jname=PurchaseBillStep&title=采购单状态&finds={"billId":1,"billStatus":1,"userId":1,"opTime":1}'
-- ;

DROP TRIGGER IF EXISTS tr_erp_vendi_bilwfw_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_vendi_bilwfw_BEFORE_INSERT` BEFORE INSERT ON `erp_vendi_bilwfw` FOR EACH ROW begin
	declare aid bigint(20);
	declare aName VARCHAR(100);

	if exists(select 1 from autopart01_crm.`erc$staff` a where a.userId = new.userId) THEN
		select a.id, a.name into aid, aName
		from autopart01_crm.`erc$staff` a where a.userId = new.userId;
		set new.empId = aid, new.empName = aName;
		if new.billStatus <> 'justcreated' then
			update erp_vendi_bil a 
			set a.lastModifiedDate = CURRENT_TIMESTAMP(), a.lastModifiedId = new.userId
			, a.lastModifiedEmpId = new.empId, a.lastModifiedEmpName = new.empName
			where a.id = new.billId;
		END IF;
-- 		if new.billStatus <> 'justcreated' and new.billStatus <> 'submitthatview' and new.billStatus <> 'checked' then
-- 			update erp_vendi_bil a 
-- 			set a.lastModifiedDate = CURRENT_TIMESTAMP(), a.lastModifiedId = new.userId, a.lastModifiedEmpId = aid, a.lastModifiedEmpName = aName
-- 			where a.id = new.billId;
-- 		end if;
	ELSE
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '新增操作记录，必须指定操作人员！';
	end if;
	set new.opTime = CURRENT_TIMESTAMP();

	if new.billStatus = 'submitthatview' then  -- 提交待审

		if exists(select 1 from erp_vendi_bilwfw a where a.billId = NEW.billId and a.billStatus = 'submitthatview' limit 1) then

			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已提交，不能重复提交！';

		end if;

	elseif new.billStatus = 'checked' then -- 通过审核
	
		if exists(select 1 from erp_vendi_bilwfw a where a.billId = NEW.billId and a.billStatus = 'checked') then
			SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '该单据已通过审核，不能重复操作！';
		end if;
		if exists(
				select 1 
				from erp_vendi_bil a 
					INNER JOIN erp_vendi_detail b on a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
					INNER JOIN erp_goodsbook g on b.goodsId = g.goodsId
				where a.id = new.billId and b.isBuy = 1 and g.dynamicQty < b.qty  limit 1
			) THEN  -- 库存不足， 生成采购订单
			-- 先将明细改成库存不足	

-- 			update erp_vendi_bil a 
-- 					INNER JOIN erp_vendi_detail b on a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
-- 					INNER JOIN erp_goodsBook g on b.goodsId = g.goodsId
-- 			set b.isEnough = 0
-- 			where a.id = new.billId and b.isBuy = 1 and g.dynamicQty < b.qty
-- 			;

			update erp_vendi_detail b INNER JOIN erp_goodsBook g on b.goodsId = g.goodsId
			set b.isEnough = 0
			where b.isBuy = 1 and g.dynamicQty < b.qty and exists(
					select 1 from erp_vendi_bil a where a.id = new.billId and a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
				)
			;

			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功修改是否可以出仓标志!';
			end if;
			-- 生成采购订单主表
-- ----------------------------------------------

			insert into erp_purch_bil( erp_inquiry_bil_id, supplierId, creatorId, createdDate
				, createdBy, empId, empName, memo)
			select DISTINCT a.erp_inquiry_bil_id, b.supplierId, new.userId, CURRENT_TIMESTAMP()
				, aName, aId, aName, concat('销售订单审核库存不足自动转入。')
			from erp_vendi_bil a INNER JOIN erp_vendi_detail b ON a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
			where a.id = new.billId AND b.isEnough = 0;

-- ----------------------------------------------
			if ROW_COUNT() = 0 THEN
				SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能生成采购订单主表!';
			end if;
			
		else	-- 库存足够， 修改状态为可以出库
			IF EXISTS(SELECT 1 FROM erp_vendi_bil a 
						INNER JOIN erp_vendi_detail b ON a.erp_inquiry_bil_id = b.erp_inquiry_bil_id 
						WHERE b.isEnough =0 AND b.isBuy = 1) THEN
				update  erp_vendi_bil a 
					INNER JOIN erp_vendi_detail b on a.erp_inquiry_bil_id = b.erp_inquiry_bil_id
				set b.isEnough = 1 
				where b.isBuy = 1 and a.id = new.billId;
				if ROW_COUNT() = 0 THEN
					SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '未能成功修改是否可以出仓标志!';
				end if;
			END IF;
		end if;
	elseif new.billStatus = 'flowaway' then -- 出仓完成, 修改出仓时间表示已完成出仓
		update erp_vendi_bil a 
		set a.outTime = CURRENT_TIME()
			, a.outUserId = new.userId, a.outEmpId = aid, a.outEmpName = aName
		where a.id = new.billId;
		-- 生成货运信息表
		insert into erp_vendi_deliv(erp_vendi_bil_id, userId, empId, empName, opTime)
		select new.billId, new.userId, new.empId, new.empName, CURRENT_TIMESTAMP()
		;
	ELSEIF new.billStatus = 'cost' THEN
		UPDATE erp_vendi_bil a 
		set a.costTime = CURRENT_TIMESTAMP()
		WHERE a.id = new.billId;
-- 	elseif new.billStatus = 'flowaway' then -- 出仓完成, 修改
	end if;
end;;
DELIMITER ;

-- DROP TRIGGER IF EXISTS tr_erp_vendi_bilwfw_AFTER_INSERT;
-- DELIMITER ;;
-- CREATE TRIGGER `tr_erp_vendi_bilwfw_AFTER_INSERT` AFTER INSERT ON `erp_vendi_bilwfw` FOR EACH ROW begin
-- 	if new.billStatus <> 'justcreated' then
-- 			update erp_vendi_bil a 
-- 			set a.lastModifiedDate = CURRENT_TIMESTAMP(), a.lastModifiedId = new.userId
-- 			, a.lastModifiedEmpId = new.empId, a.lastModifiedEmpName = new.empName
-- 			where a.id = new.billId;
-- 	END IF;
-- end;;
-- DELIMITER ;