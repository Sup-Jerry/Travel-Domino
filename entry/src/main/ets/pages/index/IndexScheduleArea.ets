import { EventEntity } from '../../model/entity/EventEntity';
import { DateGroup, TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { ConflictActionStrategy, IndexEventHandlers } from './IndexEventHandlers';
import { IndexBottomBar } from './IndexBottomBar';
import { IndexTimelineTheme, IndexTimelineView } from './IndexTimelineView';
import { IndexUnsavedActionBar, IndexUnsavedActionTheme } from './IndexUnsavedActionBar';

export type IndexScheduleVoidCallback = () => void;
export type IndexScheduleDayCollapsedCallback = (dayOffset: number) => boolean;
export type IndexScheduleDayToggleCallback = (dayOffset: number) => void;
export type IndexScheduleEventCallback = (item: EventEntity) => void;
export type IndexScheduleTravelModeCallback = (item: EventEntity, mode: number) => void;
export type IndexScheduleMinutesCallback = (item: EventEntity, minutes: number) => void;
export type IndexScheduleConflictActionCallback = (
  item: EventEntity,
  strategy: ConflictActionStrategy,
  gapMinutes: number
) => void;

export interface IndexScheduleTimelineViewProps {
  groupedEvents: DateGroup[];
  allEvents: EventEntity[];
  isArchived: boolean;
  isCompanionMode: boolean;
  showWeather: boolean;
  isPageRefreshing: boolean;
  gapsCount: number;
  theme: IndexTimelineTheme;
  onIsDayCollapsed: IndexScheduleDayCollapsedCallback;
  onToggleDay: IndexScheduleDayToggleCallback;
  onRefresh: IndexScheduleVoidCallback;
  onMoveUp: IndexScheduleEventCallback;
  onMoveDown: IndexScheduleEventCallback;
  onMainContentClick: IndexScheduleEventCallback;
  onTimeClick: IndexScheduleEventCallback;
  onTravelModeChange: IndexScheduleTravelModeCallback;
  onManualTravelInput: IndexScheduleMinutesCallback;
  onCommuteChange: IndexScheduleMinutesCallback;
  onConflictAction: IndexScheduleConflictActionCallback;
  onMoveToBacklog: IndexScheduleEventCallback;
  onDeleteEvent: IndexScheduleEventCallback;
  onOpenGapOptimize: IndexScheduleVoidCallback;
}

export interface IndexScheduleBottomBarProps {
  onFilter: IndexScheduleVoidCallback;
  onAi: IndexScheduleVoidCallback;
  onAdd: IndexScheduleVoidCallback;
  aiEnabled: boolean;
  addEnabled: boolean;
}

export interface IndexScheduleUnsavedActionBarProps {
  isVisible: boolean;
  marginBottom: number;
  theme: IndexUnsavedActionTheme;
  onUndo: IndexScheduleVoidCallback;
  onSave: IndexScheduleVoidCallback;
}

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

  onIsDayCollapsed: IndexScheduleDayCollapsedCallback = (_dayOffset: number) => false;
  onToggleDay: IndexScheduleDayToggleCallback = (_dayOffset: number) => {};
  onRefresh: IndexScheduleVoidCallback = () => {};
  onOpenEditDialog: IndexScheduleEventCallback = (_item: EventEntity) => {};
  onOpenTimeEditDialog: IndexScheduleEventCallback = (_item: EventEntity) => {};
  onGapFound: IndexScheduleEventCallback = (_item: EventEntity) => {};
  onResolveConflictAction: IndexScheduleConflictActionCallback =
    (_item: EventEntity, _strategy: ConflictActionStrategy, _gapMinutes: number) => {};
  onConfirmMoveToBacklog: IndexScheduleEventCallback = (_item: EventEntity) => {};
  onConfirmDeleteEvent: IndexScheduleEventCallback = (_item: EventEntity) => {};
  onOpenGapOptimize: IndexScheduleVoidCallback = () => {};
  onFilter: IndexScheduleVoidCallback = () => {};
  onAi: IndexScheduleVoidCallback = () => {};
  onAdd: IndexScheduleVoidCallback = () => {};
  onUndo: IndexScheduleVoidCallback = () => {};
  onSave: IndexScheduleVoidCallback = () => {};

  buildTimelineViewProps(): IndexScheduleTimelineViewProps {
    return {
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
    };
  }

  buildBottomBarProps(): IndexScheduleBottomBarProps {
    return {
      onFilter: () => this.onFilter(),
      onAi: () => this.onAi(),
      onAdd: () => this.onAdd(),
      aiEnabled: resolveIndexScheduleBottomBarAiEnabled(this.isArchived),
      addEnabled: resolveIndexScheduleBottomBarAddEnabled(this.isArchived)
    };
  }

  buildUnsavedActionBarProps(): IndexScheduleUnsavedActionBarProps {
    return {
      isVisible: this.hasUnsavedChanges,
      marginBottom: resolveIndexScheduleUnsavedMarginBottom(this.isCompanionMode),
      theme: this.unsavedTheme,
      onUndo: () => this.onUndo(),
      onSave: () => this.onSave()
    };
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        IndexTimelineView(this.buildTimelineViewProps())
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.timelineTheme.pageBg)

      if (shouldShowIndexScheduleBottomBar(this.isCompanionMode)) {
        IndexBottomBar(this.buildBottomBarProps())
          .zIndex(8)
      }

      IndexUnsavedActionBar(this.buildUnsavedActionBarProps())
    }
  }
}
