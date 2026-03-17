// 璺緞: ets/common/utils/RdbHelper.ets

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { EventEntity } from '../../model/entity/EventEntity';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlanEntity } from '../../model/entity/PlanEntity';

const TAG = 'RdbHelper';

/**
 * RdbHelper: 鍏崇郴鍨嬫暟鎹簱绠＄悊宸ュ叿 (鍗曚緥)
 */
export class RdbHelper {
  private static instance: RdbHelper;
  private rdbStore: relationalStore.RdbStore | null = null;
  private config: relationalStore.StoreConfig = {
    name: 'Travel.db', // 鏁版嵁搴撴枃浠跺悕
    securityLevel: relationalStore.SecurityLevel.S1
  };

  private constructor() {}

  /**
   * 鑾峰彇鍗曚緥瀹炰緥
   */
  public static getInstance(): RdbHelper {
    if (!RdbHelper.instance) {
      RdbHelper.instance = new RdbHelper();
    }
    return RdbHelper.instance;
  }

  /**
   * 鍒濆鍖栨暟鎹簱 (鍦?UIAbility onCreate 涓皟鐢?
   */
  public init(context: common.Context): Promise<void> {
    return new Promise((resolve, reject) => {
      relationalStore.getRdbStore(context, this.config, async (err, store) => {
        if (err) {
          hilog.error(0x0000, TAG, `Failed to get RdbStore. Code:${err.code}, Message:${err.message}`);
          reject(err);
          return;
        }

        this.rdbStore = store;

        if (this.rdbStore) {
          try {
            await this.rdbStore.executeSql(PlanEntity.SQL_CREATE_TABLE);

            await this.rdbStore.executeSql(EventEntity.SQL_CREATE_TABLE);

            if (this.rdbStore.version < 2) {
              hilog.info(0x0000, TAG, 'Start upgrading database to version 2...');

              // 閫愪釜妫€鏌ュ苟娣诲姞鍒?(浣跨敤 try-catch 闃叉鍒楀凡瀛樺湪鐨勯敊璇?
              const addColumns = [
                `ALTER TABLE ${EventEntity.TABLE_NAME} ADD COLUMN ${EventEntity.ACTUAL_START_TIME} INTEGER DEFAULT 0`,
                `ALTER TABLE ${EventEntity.TABLE_NAME} ADD COLUMN ${EventEntity.ACTUAL_END_TIME} INTEGER DEFAULT 0`,
                `ALTER TABLE ${EventEntity.TABLE_NAME} ADD COLUMN ${EventEntity.COMPLETION_STATUS} INTEGER DEFAULT 0`
              ];

              for (const sql of addColumns) {
                try {
                  await this.rdbStore.executeSql(sql);
                } catch (e) {
                  // 蹇界暐"鍒楀凡瀛樺湪"鐨勯敊璇紝淇濊瘉骞傜瓑鎬?
                  hilog.warn(0x0000, TAG, `Column might already exist: ${JSON.stringify(e)}`);
                }
              }

              // 鏍囪鐗堟湰鍙蜂负 2
              this.rdbStore.version = 2;
              hilog.info(0x0000, TAG, 'Database upgraded to version 2 successfully.');
            }
            if (this.rdbStore.version < 3) { // 淇敼鐐癸細鏂板 V3 鍗囩骇鍒嗘敮锛岀敤浜庡垱寤虹储寮?
              const createIndexSql = [
                `CREATE INDEX IF NOT EXISTS idx_event_query ON ${EventEntity.TABLE_NAME} (${EventEntity.PLAN_ID}, ${EventEntity.DEL_FLAG}, ${EventEntity.STATUS}, ${EventEntity.DAY_OFFSET}, ${EventEntity.SORT_ORDER})`,
                `CREATE INDEX IF NOT EXISTS idx_plan_query ON ${PlanEntity.TABLE_NAME} (${PlanEntity.DEL_FLAG}, ${PlanEntity.CREATED_AT})`
              ];
              for (const sql of createIndexSql) {
                await this.rdbStore.executeSql(sql);
              }
              this.rdbStore.version = 3; // 淇敼鐐癸細鏄惧紡鏇存柊鏁版嵁搴撶増鏈彿
              hilog.info(0x0000, TAG, 'Database upgraded to version 3 with indexes.');
            } // 淇敼鐐?

            if (this.rdbStore.version < 4) {
              const addRouteColumns = [
                `ALTER TABLE ${EventEntity.TABLE_NAME} ADD COLUMN ${EventEntity.IS_TRAVEL_MANUAL} INTEGER DEFAULT 0`,
                `ALTER TABLE ${PlanEntity.TABLE_NAME} ADD COLUMN ${PlanEntity.ENABLE_AUTO_AMAP_ROUTE} INTEGER DEFAULT 1`
              ];
              for (const sql of addRouteColumns) {
                try {
                  await this.rdbStore.executeSql(sql);
                } catch (e) {
                  hilog.warn(0x0000, TAG, `Column might already exist: ${JSON.stringify(e)}`);
                }
              }
              this.rdbStore.version = 4;
              hilog.info(0x0000, TAG, 'Database upgraded to version 4 with route control fields.');
            }

            if (this.rdbStore.version < 5) {
              const addStrategyColumns = [
                `ALTER TABLE ${PlanEntity.TABLE_NAME} ADD COLUMN ${PlanEntity.STRATEGY_MODE} INTEGER DEFAULT 0`,
                `ALTER TABLE ${PlanEntity.TABLE_NAME} ADD COLUMN ${PlanEntity.STRATEGY_VERSION} INTEGER DEFAULT 1`,
                `ALTER TABLE ${PlanEntity.TABLE_NAME} ADD COLUMN ${PlanEntity.LAST_AI_PROMPT} TEXT`,
                `ALTER TABLE ${PlanEntity.TABLE_NAME} ADD COLUMN ${PlanEntity.LAST_STRATEGY_EXPLANATION} TEXT`
              ];
              for (const sql of addStrategyColumns) {
                try {
                  await this.rdbStore.executeSql(sql);
                } catch (e) {
                  hilog.warn(0x0000, TAG, `Column might already exist: ${JSON.stringify(e)}`);
                }
              }
              this.rdbStore.version = 5;
              hilog.info(0x0000, TAG, 'Database upgraded to version 5 with strategy fields.');
            }

            hilog.info(0x0000, TAG, 'Succeeded in creating tables: plans & events');
            resolve();
          } catch (sqlErr) {
            hilog.error(0x0000, TAG, `Failed to execute SQL. Message:${JSON.stringify(sqlErr)}`);
            reject(sqlErr);
          }
        }
      });
    });
  }

  /**
   * 鑾峰彇 RdbStore 瀵硅薄 (渚?DAO 灞傝皟鐢?
   */
  public getRdbStore(): relationalStore.RdbStore | null {
    if (!this.rdbStore) {
      hilog.error(0x0000, TAG, 'RdbStore is not initialized!');
    }
    return this.rdbStore;
  }
}
