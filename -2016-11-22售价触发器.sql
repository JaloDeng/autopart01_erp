-- 14.修改售价时
DELIMITER $$

USE `autopart01_erp`$$
DROP TRIGGER IF EXISTS tr_erp$vendi_detail_BEFORE_UPDATE$$
CREATE DEFINER = CURRENT_USER TRIGGER `tr_erp$vendi_detail_BEFORE_UPDATE` BEFORE UPDATE ON `erp$vendi_detail` FOR EACH ROW
BEGIN
	declare floatMin,floatMax,priceMin,priceMax decimal(20,6);
	declare message VARCHAR(50);
	-- 销售改售价时候
	if(new.`priceSell` <> old.`priceSell` and new.`priceCome` is not null) then 
		select cptr.`floatMin`,cptr.`floatMax` into floatMin,floatMax from `autopart01_erp`.`erp$conf_price_tune_rule` cptr where cptr.`goodsId` = new.`goodsId`; 
		set priceMin = new.`priceCome` * floatMin;
		set priceMax = new.`priceCome` * floatMax;
		if(new.`priceSell` < priceMin) then 
			set message = CONCAT('售价不能低于',priceMin,'.');
			signal sqlstate 'QZ002' set message_text = message;
		elseif(new.`priceSell` > priceMax) then 
			set message = CONCAT('售价不能高于',priceMax,'.');
			signal sqlstate 'QZ002' set message_text = message;
		end if;
		set new.`priceSumSell` = new.`priceSell` * new.`amount`;
	end if;

END$$
DELIMITER ;