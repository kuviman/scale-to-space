const geng = import "../src/lib/geng/_lib.ks";

const App = newtype {
    .a :: Box[Int32],
};

@eval (impl App as geng.App = {
    .init = () => (
        { .a = Box_new(123) }
    ),
    .update = (self, delta_time) => (),
    .handle_event = (self, event) => (),
    .draw = (self) => (),
});

geng.run[App]();
