/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @format
 * @f;pw
 */

'use strict'; // TODO(OSS Candidate ISS#2710739)

const React = require('react');
const {Platform, StyleSheet, Text, View} = require('react-native');

type State = {};

class DarkModeExample extends React.Component<{}, State> {
  state: State = {};

  render() {
    return (
      <View>
        <Text>Dark Mode Examples</Text>
      </View>
    );
  }
}

var styles = StyleSheet.create({
  textInput: {
    ...Platform.select({
      ios: {
        color: {semantic: 'textColor'},
        backgroundColor: {semantic: 'textBackgroundColor'},
        borderColor: {semantic: 'gridColor'},
      },
      default: {
        borderColor: '#0f0f0f',
      },
    }),
    borderWidth: StyleSheet.hairlineWidth,
    flex: 1,
    fontSize: 13,
    padding: 4,
  },
});

exports.title = 'Dark Mode Example';
exports.description =
  'Examples that show how Dark Mode may be implemented in an app.';
exports.examples = [
  {
    title: 'Dark Mode Example',
    render: function(): React.Element<any> {
      return <DarkModeExample />;
    },
  },
];
