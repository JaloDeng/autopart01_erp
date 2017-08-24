-- *****************************************************************************************************
-- 创建存储过程 p_inventory_task_new, 新建盘点任务单
-- *****************************************************************************************************
DROP PROCEDURE IF EXISTS p_inventory_task_new;
DELIMITER ;;
CREATE PROCEDURE p_inventory_task_new(
)
BEGIN

	DECLARE uid, lid bigint;

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION 
		BEGIN
			ROLLBACK;
			RESIGNAL;
		END;

	START TRANSACTION;

		-- 获取系统用户ID
		SELECT u.ID INTO uid FROM autopart01_security.`sec$user` u WHERE u.username = 'system'; 

		IF uid > 0 THEN
			-- 新增盘点任务单
			INSERT INTO ers_inventory_task(lastModifiedId, memo) SELECT uid, '每月系统自动创建盘点任务单！';
			-- 获取主键ID
			SET lid = LAST_INSERT_ID();
			-- 新增盘点单(仓库库存大于0的商品)
			INSERT INTO ers_inventory(ers_inventory_task_id, goodsId, ers_shelfattr_id, lastModifiedId) 
			SELECT lid, sb.goodsId, sb.ers_shelfattr_id, uid
			FROM ers_shelfbook sb 
			WHERE sb.qty > 0 GROUP BY sb.goodsId, sb.ers_shelfattr_id
			;
		END IF;

	COMMIT;

END;;
DELIMITER ;