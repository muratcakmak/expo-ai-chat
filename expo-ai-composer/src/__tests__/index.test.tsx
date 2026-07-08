import { createElement, createRef } from "react";
import TestRenderer, { act } from "react-test-renderer";

// Imported after the mocks conceptually; jest hoists jest.mock above all imports.
import * as ExpoAiComposer from "..";
import type { AiComposerRef } from "../ExpoAiComposer.types";

// Tell React that act(...) is supported in this environment (silences the
// "not configured to support act" warning under react-test-renderer).
(
  globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }
).IS_REACT_ACT_ENVIRONMENT = true;

// Mock the native layer. `requireNativeView` returns a component that records the
// props it receives and exposes focus/blur/clear on its ref (mirroring how
// requireNativeView assigns native view functions to the component prototype).
// `requireNativeModule` returns the module constants read by `constants`.
jest.mock("expo", () => {
  const React = require("react");

  const nativeMethods = {
    focus: jest.fn(),
    blur: jest.fn(),
    clear: jest.fn(),
  };
  const recordedProps: { current: Record<string, any> | null } = {
    current: null,
  };

  const requireNativeView = jest.fn(() => {
    const MockNativeView = React.forwardRef((props: any, ref: any) => {
      recordedProps.current = props;
      React.useImperativeHandle(ref, () => nativeMethods, []);
      return React.createElement("NativeAiComposer", { testID: "native-view" });
    });
    MockNativeView.displayName = "MockNativeView";
    return MockNativeView;
  });

  const requireNativeModule = jest.fn(() => ({
    defaultMinHeight: 48,
    defaultMaxHeight: 120,
    contentGap: 0,
  }));

  class NativeModule {}

  return {
    __esModule: true,
    requireNativeView,
    requireNativeModule,
    NativeModule,
    // Test hooks for asserting on the mocked native layer.
    __mock: { nativeMethods, recordedProps },
  };
});

// Lightweight react-native mock so the component tree can render under
// react-test-renderer in a Node environment (host components as string tags).
jest.mock("react-native", () => ({
  __esModule: true,
  View: "View",
  StyleSheet: {
    create: (styles: Record<string, unknown>) => styles,
    flatten: (style: unknown) => style,
  },
}));

const { nativeMethods, recordedProps } = (
  jest.requireMock("expo") as {
    __mock: {
      nativeMethods: { focus: jest.Mock; blur: jest.Mock; clear: jest.Mock };
      recordedProps: { current: Record<string, any> | null };
    };
  }
).__mock;

const { AiComposer, AiComposerWrapper, ExpoAiComposerModule, constants } =
  ExpoAiComposer;

function renderComposer(props: Record<string, unknown> = {}) {
  let renderer!: TestRenderer.ReactTestRenderer;
  act(() => {
    renderer = TestRenderer.create(createElement(AiComposer as any, props));
  });
  return renderer;
}

beforeEach(() => {
  recordedProps.current = null;
});

describe("public API surface", () => {
  it("exports the components, module, and constants", () => {
    expect(AiComposer).toBeDefined();
    expect(AiComposerWrapper).toBeDefined();
    expect(ExpoAiComposerModule).toBeDefined();
    expect(constants).toEqual({
      defaultMinHeight: 48,
      defaultMaxHeight: 120,
      contentGap: 0,
    });
  });
});

describe("send button behavior", () => {
  it("forces showSendButton false when a trailingAccessory is provided", () => {
    renderComposer({
      trailingAccessory: createElement("View", { testID: "trailing" }),
    });
    expect(recordedProps.current?.showSendButton).toBe(false);
  });

  it("renders a bare native view (no wrapper) when no accessories are provided", () => {
    const renderer = renderComposer();
    const tree = renderer.toJSON() as TestRenderer.ReactTestRendererJSON;

    // Without accessories the root rendered node is the native view itself.
    expect(tree.props.testID).toBe("native-view");
    // Default send button visibility is preserved.
    expect(recordedProps.current?.showSendButton).toBe(true);
  });
});

describe("native event unwrapping", () => {
  it("unwraps nativeEvent and calls the public callbacks with the inner value", () => {
    const onSend = jest.fn();
    const onHeightChange = jest.fn();
    renderComposer({ onSend, onHeightChange });

    // Fire the wrapped native events the way the native view would.
    act(() => {
      recordedProps.current?.onSend({ nativeEvent: { text: "hello" } });
      recordedProps.current?.onHeightChange({ nativeEvent: { height: 64 } });
    });

    // Consumers receive the unwrapped value, not the raw event object.
    expect(onSend).toHaveBeenCalledWith("hello");
    expect(onHeightChange).toHaveBeenCalledWith(64);
  });

  it("is a no-op when the matching callback prop is undefined", () => {
    // No onSend provided: the `?.` guard in the handler should swallow the call.
    renderComposer();

    expect(() =>
      act(() => {
        recordedProps.current?.onSend({ nativeEvent: { text: "hello" } });
      })
    ).not.toThrow();
  });
});

describe("imperative ref", () => {
  it("exposes focus/blur/clear and delegates each to the native view ref", () => {
    const ref = createRef<AiComposerRef>();
    act(() => {
      TestRenderer.create(createElement(AiComposer as any, { ref }));
    });

    expect(typeof ref.current?.focus).toBe("function");
    expect(typeof ref.current?.blur).toBe("function");
    expect(typeof ref.current?.clear).toBe("function");

    act(() => {
      ref.current?.focus();
      ref.current?.blur();
      ref.current?.clear();
    });

    expect(nativeMethods.focus).toHaveBeenCalledTimes(1);
    expect(nativeMethods.blur).toHaveBeenCalledTimes(1);
    expect(nativeMethods.clear).toHaveBeenCalledTimes(1);
  });
});
