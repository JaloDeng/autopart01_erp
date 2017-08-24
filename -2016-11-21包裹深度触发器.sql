-- 1.包裹深度触发器
DELIMITER $$

USE `autopart01_erp`$$
DROP TRIGGER IF EXISTS tr_ers$stock_packageattr_BEFORE_INSERT$$
CREATE DEFINER = CURRENT_USER TRIGGER `tr_ers$stock_packageattr_BEFORE_INSERT` BEFORE INSERT ON `ers$stock_packageattr` FOR EACH ROW
BEGIN
    if new.`parentId` is null then 
			set new.`degree` = 1;
    else
			set new.`degree` = (select spa.`degree`+1 from `ers$stock_packageattr` as spa where spa.`id` = new.`parentId`);
	end if;
END$$
DELIMITER ;
