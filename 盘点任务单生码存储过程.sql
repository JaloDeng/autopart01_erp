DROP PROCEDURE IF EXISTS `p_inventory_snCode`;
DELIMITER ;;
CREATE PROCEDURE `p_inventory_snCode`(
	aids VARCHAR(65535) CHARSET latin1 -- 采购单ID erp_purch_bil.id(集合，用xml格式) 
	, itid bigint(20) -- 盘点任务表ID
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, qty INT(11) -- 采购单个数
)
BEGIN

	DECLARE aSnCodeTime datetime;
	DECLARE i INT DEFAULT 1;
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;
	
	START TRANSACTION;
	
	-- 获取盘点任务表生码时间
	SELECT it.sncodeTime INTO aSnCodeTime FROM ers_inventory_task it WHERE it.id = itid;
	IF aSnCodeTime > 0 THEN
		SIGNAL SQLSTATE 'QZ000' SET MESSAGE_TEXT = '盘点单已批量生码，不能重复操作！！';
	END IF;

	-- 循环生码
	WHILE i < qty+1 DO
		CALL p_purchDetail_snCode(ExtractValue(aids, '//a[$i]'), uId);
		SET i = i+1;
	END WHILE;

	-- 记录生码时间
	UPDATE ers_inventory_task it SET it.sncodeTime = NOW(), it.lastModifiedId = uId WHERE it.id = itid;

	COMMIT;  

END;;
DELIMITER ;