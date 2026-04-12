import { PlanBottomActionBar } from '../components/views/BottomNavBar';

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
  onFilter: () => void = () => {};
  onAi: () => void = () => {};
  onAdd: () => void = () => {};

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
