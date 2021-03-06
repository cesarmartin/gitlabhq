import Vue from 'vue';
import boardsStore from '~/boards/stores/boards_store';
import BoardBlankState from '~/boards/components/board_blank_state.vue';
import { mockBoardService } from './mock_data';

describe('Boards blank state', () => {
  let vm;
  let fail = false;

  beforeEach((done) => {
    const Comp = Vue.extend(BoardBlankState);

    boardsStore.create();
    gl.boardService = mockBoardService();

    spyOn(gl.boardService, 'generateDefaultLists').and.callFake(() => new Promise((resolve, reject) => {
      if (fail) {
        reject();
      } else {
        resolve({
          data: [{
            id: 1,
            title: 'To Do',
            label: { id: 1 },
          }, {
            id: 2,
            title: 'Doing',
            label: { id: 2 },
          }],
        });
      }
    }));

    vm = new Comp();

    setTimeout(() => {
      vm.$mount();
      done();
    });
  });

  it('renders pre-defined labels', () => {
    expect(
      vm.$el.querySelectorAll('.board-blank-state-list li').length,
    ).toBe(2);

    expect(
      vm.$el.querySelectorAll('.board-blank-state-list li')[0].textContent.trim(),
    ).toEqual('To Do');

    expect(
      vm.$el.querySelectorAll('.board-blank-state-list li')[1].textContent.trim(),
    ).toEqual('Doing');
  });

  it('clears blank state', (done) => {
    vm.$el.querySelector('.btn-default').click();

    setTimeout(() => {
      expect(boardsStore.welcomeIsHidden()).toBeTruthy();

      done();
    });
  });

  it('creates pre-defined labels', (done) => {
    vm.$el.querySelector('.btn-success').click();

    setTimeout(() => {
      expect(boardsStore.state.lists.length).toBe(2);
      expect(boardsStore.state.lists[0].title).toEqual('To Do');
      expect(boardsStore.state.lists[1].title).toEqual('Doing');

      done();
    });
  });

  it('resets the store if request fails', (done) => {
    fail = true;

    vm.$el.querySelector('.btn-success').click();

    setTimeout(() => {
      expect(boardsStore.welcomeIsHidden()).toBeFalsy();
      expect(boardsStore.state.lists.length).toBe(1);

      done();
    });
  });
});
