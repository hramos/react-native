/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @format
 * @flow
 */

'use strict';

const React = require('react');
const {
  Platform,
  SectionList,
  StyleSheet,
  Text,
  TouchableHighlight,
  View,
} = require('react-native');
const RNTesterActions = require('../utils/RNTesterActions');
const RNTesterExampleFilter = require('./RNTesterExampleFilter');

import type {RNTesterExample} from '../types/RNTesterTypes';
import type {ViewStyleProp} from '../../../Libraries/StyleSheet/StyleSheet';

type Props = {
  onNavigate: Function,
  list: {
    ComponentExamples: Array<RNTesterExample>,
    APIExamples: Array<RNTesterExample>,
  },
  style?: ?ViewStyleProp,
};

class RowComponent extends React.PureComponent<{
  item: Object,
  onNavigate: Function,
  onPress?: Function,
  onShowUnderlay?: Function,
  onHideUnderlay?: Function,
}> {
  _onPress = () => {
    if (this.props.onPress) {
      this.props.onPress();
      return;
    }
    this.props.onNavigate(RNTesterActions.ExampleAction(this.props.item.key));
  };
  render() {
    const {item} = this.props;
    return (
      <TouchableHighlight
        onShowUnderlay={this.props.onShowUnderlay}
        onHideUnderlay={this.props.onHideUnderlay}
        onPress={this._onPress}>
        <View style={styles.row}>
          <Text style={styles.rowTitleText}>{item.module.title}</Text>
          <Text style={styles.rowDetailText}>{item.module.description}</Text>
        </View>
      </TouchableHighlight>
    );
  }
}

const renderSectionHeader = ({section}) => (
  <Text style={styles.sectionHeader}>{section.title}</Text>
);

class RNTesterExampleList extends React.Component<Props, $FlowFixMeState> {
  render() {
    const filter = ({example, filterRegex}) =>
      filterRegex.test(example.module.title) &&
      (!Platform.isTV || example.supportsTVOS);

    const sections = [
      {
        data: this.props.list.ComponentExamples,
        title: 'COMPONENTS',
        key: 'c',
      },
      {
        data: this.props.list.APIExamples,
        title: 'APIS',
        key: 'a',
      },
    ];

    return (
      <View style={[styles.listContainer, this.props.style]}>
        {this._renderTitleRow()}
        <RNTesterExampleFilter
          testID="explorer_search"
          sections={sections}
          filter={filter}
          render={({filteredSections}) => (
            <SectionList
              ItemSeparatorComponent={ItemSeparator}
              contentContainerStyle={styles.sectionListContentContainer}
              style={styles.list}
              sections={filteredSections}
              renderItem={this._renderItem}
              enableEmptySections={true}
              itemShouldUpdate={this._itemShouldUpdate}
              keyboardShouldPersistTaps="handled"
              automaticallyAdjustContentInsets={false}
              keyboardDismissMode="on-drag"
              renderSectionHeader={renderSectionHeader}
              backgroundColor={Platform.select({
                ios: 'transparent',
                default: undefined,
              })}
            />
          )}
        />
      </View>
    );
  }

  _itemShouldUpdate(curr, prev) {
    return curr.item !== prev.item;
  }

  _renderItem = ({item, separators}) => (
    <RowComponent
      item={item}
      onNavigate={this.props.onNavigate}
      onShowUnderlay={separators.highlight}
      onHideUnderlay={separators.unhighlight}
    />
  );

  _renderTitleRow(): ?React.Element<any> {
    /* $FlowFixMe(>=0.68.0 site=react_native_fb) This comment suppresses an
     * error found when Flow v0.68 was deployed. To see the error delete this
     * comment and run Flow. */
    if (!this.props.displayTitleRow) {
      return null;
    }
    return (
      <RowComponent
        item={{
          module: {
            title: 'RNTester',
            description: 'React Native Examples',
          },
        }}
        onNavigate={this.props.onNavigate}
        onPress={() => {
          this.props.onNavigate(RNTesterActions.ExampleList());
        }}
      />
    );
  }

  _handleRowPress(exampleKey: string): void {
    this.props.onNavigate(RNTesterActions.ExampleAction(exampleKey));
  }
}

const ItemSeparator = ({highlighted}) => (
  <View style={highlighted ? styles.separatorHighlighted : styles.separator} />
);

const styles = StyleSheet.create({
  listContainer: {
    flex: 1,
  },
  list: {
    ...Platform.select({
      ios: {
        backgroundColor: {semantic: 'systemBackgroundColor'},
      },
      default: {
        backgroundColor: '#eeeeee',
      },
    }),
  },
  sectionHeader: {
    ...Platform.select({
      ios: {
        backgroundColor: {
          semantic: 'systemGroupedBackgroundColor',
        },
        color: {semantic: 'secondaryLabelColor'},
      },
      default: {
        backgroundColor: '#eeeeee',
        color: 'black',
      },
    }),
    padding: 5,
    fontWeight: '500',
    fontSize: 11,
  },
  row: {
    ...Platform.select({
      ios: {
        backgroundColor: {semantic: 'secondarySystemGroupedBackgroundColor'},
      },
      default: {
        backgroundColor: 'white',
      },
    }),
    justifyContent: 'center',
    paddingHorizontal: 15,
    paddingVertical: 8,
  },
  separator: {
    height: StyleSheet.hairlineWidth,
    ...Platform.select({
      ios: {
        backgroundColor: {semantic: 'separatorColor'},
      },
      default: {
        backgroundColor: '#bbbbbb',
      },
    }),
    marginLeft: 15,
  },
  separatorHighlighted: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: 'rgb(217, 217, 217)',
  },
  sectionListContentContainer: Platform.select({
    ios: {backgroundColor: {semantic: 'separatorColor'}},
    default: {backgroundColor: 'white'},
  }),
  rowTitleText: {
    fontSize: 17,
    fontWeight: '500',
    ...Platform.select({
      ios: {
        color: {semantic: 'labelColor'},
      },
      default: {
        color: 'black',
      },
    }),
  },
  rowDetailText: {
    fontSize: 15,
    color: '#888888',
    lineHeight: 20,
  },
});

module.exports = RNTesterExampleList;
