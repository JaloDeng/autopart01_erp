-- 17.生产条码序号函数
DELIMITER $$

DROP function IF EXISTS `uf_ers_stock_packageBook_getMaxSnCode`;
CREATE DEFINER=`root`@`localhost` FUNCTION `uf_ers_stock_packageBook_getMaxSnCode`(`goodsId` bigint(20)) RETURNS varchar(255) CHARSET utf8
BEGIN
	declare snCode varchar(255);
	select max(substring(spb.`snCode`,9,6)) into snCode from `autopart01_erp`.`ers$stock_packageBook` spb where left(spb.`snCode`,8) = date_format(now(),'%Y%m%d') and spb.`goodsId` = goodsId;
  if snCode is null then 
			return '000001';
	else 
			return LPAD(snCode+1,6,0);
    end if;
END$$

DELIMITER ;



-- 18.配件互换码
DELIMITER $$

DROP function IF EXISTS `uf_erp_goods_getExchangeCode`;
CREATE DEFINER=`root`@`localhost` FUNCTION `uf_erp_goods_getExchangeCode`(`goodsId` bigint(20)) RETURNS varchar(255) CHARSET utf8
BEGIN
	declare exchangeCode varchar(255);
	select g.`exchangeCode` into exchangeCode from `autopart01_erp`.`erp_goods` g where g.`id` = goodsId;
    if exchangeCode is null then 
			signal sqlstate 'QZ001' set message_text = '该配件在配件表中配件表中没有互换码';
    end if;
	return exchangeCode;
END$$

DELIMITER ;