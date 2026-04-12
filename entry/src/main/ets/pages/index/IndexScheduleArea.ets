import { EventEntity } from '../../model/entity/EventEntity';
import { DateGroup, TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { ConflictActionStrategy, IndexEventHandlers } from './IndexEventHandlers';
import { IndexBottomBar } from './IndexBottomBar';
import { IndexTimelineTheme, IndexTimelineView } from './IndexTimelineView';
import { IndexUnsavedActionBar, IndexUnsavedActionTheme } from './IndexUnsavedActionBar';

export function shouldShowIndexScheduleBottomBar(isCompanionMode: boolean): boolean {
  return !isCompanionMode;
}

export function resolveIndexScheduleBottomBarAiEnabled(isArchived: boolean): boolean {
  return !isArchived;
}

export function resolveIndexScheduleBottomBarAddEnabled(isArchived: boolean): boolean {
  return !isArchived;
}

export function resolveIndexScheduleUnsavedMarginBottom(isCompanionMode: boolean): number {
  return isCompanionMode ? 30 : 96;
}

@Component
export struct IndexScheduleArea {
  @Prop vm: TimelineViewModel = new TimelineViewModel();
  @Prop groupedEvents: DateGroup[] = [];
  @Prop allEvents: EventEntity[] = [];
  @Prop isArchived: boolean = false;
  @Prop isCompanionMode: boolean = false;
  @Prop showWeather: boolean = false;
  @Prop isPageRefreshing: boolean = false;
  @Prop gapsCount: number = 0;
  @Prop hasUnsavedChanges: boolean = false;
  @Prop timelineTheme: IndexTimelineTheme = {
    pageBg: '#F6F8FC',
    textPrimary: '#1F2937',
    textSecondary: '#5B6B82',
    textTertiary: '#8FA1B8',
    warning: '#C58A2A'
  };
  @Prop unsavedTheme: IndexUnsavedActionTheme = {
    textPrimary: '#1F2937',
    textSecondary: '#5B6B82',
    divider: '#E7EDF5',
    primary: '#2F7DFF',
    cardBg: '#FFFFFF'
  };

  onIsDayCollapsed: (dayOffset: number) => boolean = (_dayOffset: number) => false;
  onToggleDay: (dayOffset: number) => void = (_dayOffset: number) => {};
  onRefresh: () => void = () => {};
  onOpenEditDialog: (item: EventEntity) => void = (_item: EventEntity) => {};
  onOpenTimeEditDialog: (item: EventEntity) => void = (_item: EventEntity) => {};
  onGapFound: (item: EventEntity) => void = (_item: EventEntity) => {};
  onResolveConflictAction: (item: EventEntity, strategy: ConflictActionStrategy, gapMinutes: number) => void =
    (_item: EventEntity, _strategy: ConflictActionStrategy, _gapMinutes: number) => {};
  onConfirmMoveToBacklog: (item: EventEntity) => void = (_item: EventEntity) => {};
  onConfirmDeleteEvent: (item: EventEntity) => void = (_item: EventEntity) => {};
  onOpenGapOptimize: () => void = () => {};
  onFilter: () => void = () => {};
  onAi: () => void = () => {};
  onAdd: () => void = () => {};
  onUndo: () => void = () => {};
  onSave: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        IndexTimelineView({
          groupedEvents: this.groupedEvents,
          allEvents: this.allEvents,
          isArchived: this.isArchived,
          isCompanionMode: this.isCompanionMode,
          showWeather: this.showWeather,
          isPageRefreshing: this.isPageRefreshing,
          gapsCount: this.gapsCount,
          theme: this.timelineTheme,
          onIsDayCollapsed: (dayOffset: number) => this.onIsDayCollapsed(dayOffset),
          onToggleDay: (dayOffset: number) => this.onToggleDay(dayOffset),
          onRefresh: () => this.onRefresh(),
          onMoveUp: (item: EventEntity) => IndexEventHandlers.handleMoveUp(this.vm, item),
          onMoveDown: (item: EventEntity) => IndexEventHandlers.handleMoveDown(this.vm, item),
          onMainContentClick: (item: EventEntity) => {
            IndexEventHandlers.handleEditItem(this.isArchived, item, (event: EventEntity) => {
              this.onOpenEditDialog(event);
            });
          },
          onTimeClick: (item: EventEntity) => {
            IndexEventHandlers.handleTimeClick(this.isArchived, item, (event: EventEntity) => {
              this.onOpenTimeEditDialog(event);
            });
          },
          onTravelModeChange: (item: EventEntity, mode: number) => IndexEventHandlers.handleTravelModeChange(this.vm, item, mode),
          onManualTravelInput: (item: EventEntity, minutes: number) => IndexEventHandlers.handleManualTravelInput(this.vm, item, minutes),
          onCommuteChange: (item: EventEntity, minutes: number) => {
            IndexEventHandlers.handleCommuteChange(this.vm, item, minutes, this.onGapFound);
          },
          onConflictAction: (item: EventEntity, strategy: ConflictActionStrategy, gapMinutes: number) => {
            IndexEventHandlers.handleDateConflict(
              this.isArchived,
              item,
              strategy,
              gapMinutes,
              (event: EventEntity, action: ConflictActionStrategy, gap: number) => {
                this.onResolveConflictAction(event, action, gap);
              }
            );
          },
          onMoveToBacklog: (item: EventEntity) => {
            IndexEventHandlers.handleMoveToBacklog(item, (event: EventEntity) => {
              this.onConfirmMoveToBacklog(event);
            });
          },
          onDeleteEvent: (item: EventEntity) => {
            IndexEventHandlers.handleDeleteItem(item, (event: EventEntity) => {
              this.onConfirmDeleteEvent(event);
            });
          },
          onOpenGapOptimize: () => this.onOpenGapOptimize()
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.timelineTheme.pageBg)

      if (shouldShowIndexScheduleBottomBar(this.isCompanionMode)) {
        IndexBottomBar({
          onFilter: () => this.onFilter(),
          onAi: () => this.onAi(),
          onAdd: () => this.onAdd(),
          aiEnabled: resolveIndexScheduleBottomBarAiEnabled(this.isArchived),
          addEnabled: resolveIndexScheduleBottomBarAddEnabled(this.isArchived)
        })
          .zIndex(8)
      }

      IndexUnsavedActionBar({
        isVisible: this.hasUnsavedChanges,
        marginBottom: resolveIndexScheduleUnsavedMarginBottom(this.isCompanionMode),
        theme: this.unsavedTheme,
        onUndo: () => this.onUndo(),
        onSave: () => this.onSave()
      })
    }
  }
}
