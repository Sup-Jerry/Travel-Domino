import { PlanBottomActionBar } from '../components/views/BottomNavBar';

type IndexBottomBarVoidAction = () => void;

export function shouldEnableIndexBottomBarAi(aiEnabled: boolean): boolean {
  return aiEnabled;
}

export function shouldEnableIndexBottomBarAdd(addEnabled: boolean): boolean {
  return addEnabled;
}

@Component
export struct IndexBottomBar {
  @Prop aiEnabled: boolean = true;
  @Prop addEnabled: boolean = true;
  onFilter: IndexBottomBarVoidAction = () => {};
  onAi: IndexBottomBarVoidAction = () => {};
  onAdd: IndexBottomBarVoidAction = () => {};

  build() {
    PlanBottomActionBar({
      onFilter: () => this.onFilter(),
      onAi: () => this.onAi(),
      onAdd: () => this.onAdd(),
      aiEnabled: shouldEnableIndexBottomBarAi(this.aiEnabled),
      addEnabled: shouldEnableIndexBottomBarAdd(this.addEnabled)
    });
  }
}
