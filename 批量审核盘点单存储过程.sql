DROP PROCEDURE IF EXISTS `p_check_inventory`;
DELIMITER ;;
CREATE PROCEDURE `p_check_inventory`(
	aids VARCHAR(65535) CHARSET latin1 -- 盘点单ID ers_inventory.id(集合，用xml格式) 
	, uId bigint(20)	-- 用户ID  autopart01_security.sec$staff.userId
	, qty INT(11) -- 盘点单个数
)
BEGIN

	DECLARE i INT DEFAULT 1;
	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;
	
	START TRANSACTION;

	WHILE i < qty+1 DO
		-- 盘点单审核通过
		UPDATE ers_inventory i SET i.isCheck = 1, i.checkUserId = uId, i.lastModifiedId = uId WHERE i.id = ExtractValue(aids, '//a[$i]');
		SET i = i+1;
	END WHILE;

	COMMIT;  

END;;
DELIMITER ;