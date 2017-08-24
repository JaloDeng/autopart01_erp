-- DROP TABLE IF EXISTS erp_suppliersgoods;
-- CREATE TABLE `erp_suppliersgoods` (
--   `crm_suppliers_id` int(11) NOT NULL COMMENT '供应商ID。引用另一个数据库的表，触发器要检查是否存在',
--   `ers_packageAttr_id` bigint(20) NOT NULL COMMENT '包装ID',
--   `goodsId` bigint(20) DEFAULT NULL COMMENT '商品编码。冗余字段，跟随包装ID变化',
--   `newPrice` decimal(20,4) DEFAULT '0.0000' COMMENT '最新进货价',
--   `newSalesPrice` decimal(20,4) DEFAULT '0.0000' COMMENT '最新售价',
--   `exchangeCode` varchar(255) DEFAULT NULL COMMENT '交换码',
--   PRIMARY KEY (`crm_suppliers_id`,`ers_packageAttr_id`),
--   KEY `erp_suppliersGoods_ers_packageAttr_id_idx` (`ers_packageAttr_id`) USING BTREE,
--   KEY `erp_suppliersGoods_goods_idx` (`goodsId`) USING BTREE,
--   KEY `erp_suppliersGoods_exchangeCode_idx` (`exchangeCode`) USING BTREE,
--   CONSTRAINT `fk_erp_suppliersGoods_ers_packageAttr_id` FOREIGN KEY (`ers_packageAttr_id`) REFERENCES `ers_packageattr` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='商品供应商'
-- ;

DROP TRIGGER IF EXISTS tr_erp_suppliersgoods_BEFORE_INSERT;
DELIMITER ;;
CREATE TRIGGER `tr_erp_suppliersgoods_BEFORE_INSERT` BEFORE INSERT ON `erp_suppliersgoods` FOR EACH ROW BEGIN
	IF new.exchangeCode <> '' THEN 
		IF EXISTS(SELECT 1 FROM erp_suppliersgoods a WHERE a.goodsId = new.goodsId AND a.crm_suppliers_id = new.crm_suppliers_id 
							AND a.exchangeCode <> '' LIMIT 1 ) THEN
			SET new.exchangeCode = (SELECT a.exchangeCode FROM erp_suppliersgoods a 
															WHERE a.goodsId = new.goodsId AND a.crm_suppliers_id = new.crm_suppliers_id 
															AND a.exchangeCode <> '' LIMIT 1 );
		END IF;
	END IF;
end;;
DELIMITER ;