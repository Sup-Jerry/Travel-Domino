import { PlanBottomActionBar } from '../components/views/BottomNavBar';

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
      aiEnabled: this.aiEnabled,
      addEnabled: this.addEnabled
    });
  }
}
